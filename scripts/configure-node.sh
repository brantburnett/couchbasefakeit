#!/bin/bash
set -m

/entrypoint.sh couchbase-server &

if [ ! -e "/nodestatus/initialized" ] ; then
	CB_VERSION=$(cat /opt/couchbase/VERSION.txt | grep -o "^[0-9]*\.[0-9]*\.[0-9]*")

	echo "Initializing Couchbase Server $CB_VERSION..."

	if [[ $CB_VERSION > "5." && $CB_INDEXSTORAGE == "forestdb" ]]; then
		# Couchbase 5.0 and later doesn't support forestdb, switch to plasma instead
		CB_INDEXSTORAGE=plasma

		echo "Switching from forestdb to plasma for index storage."		
	fi
	
	sleep 5

	# Configure cluster, first request may need more time so retry
	for attempt in $(seq 10)
	do
		curl -Ss http://127.0.0.1:8091/pools/default -d memoryQuota=$CB_DATARAM -d indexMemoryQuota=$CB_INDEXRAM -d ftsMemoryQuota=$CB_SEARCHRAM \
		&& echo \
		&& break

		echo "Waiting for Couchbase startup..."
		sleep 3
	done

	curl -Ss http://127.0.0.1:8091/node/controller/setupServices -d services=${CB_SERVICES//,/%2C} && echo
	curl -Ss http://127.0.0.1:8091/settings/indexes -d storageMode=$CB_INDEXSTORAGE && echo
	curl -Ss http://127.0.0.1:8091/settings/web -d port=8091 -d "username=$CB_USERNAME" -d "password=$CB_PASSWORD" && echo

	if [[ $CB_SERVICES == *"n1ql"* ]]; then
		# Wait for the query service to be up and running
		for attempt in $(seq 5)
		do
			curl -s http://127.0.0.1:8093/admin/ping > /dev/null \
			&& break

			echo "Waiting for query service..."
			sleep 1
		done
	fi

	if [[ $CB_SERVICES == *"fts"* ]]; then
		# Wait for the FTS service to be up and running
		for attempt in $(seq 5)
		do
			curl -s http://127.0.0.1:8094/api/ping > /dev/null \
			&& break

			echo "Waiting for FTS service..."
			sleep 1
		done
	fi

	# Create buckets defined in /startup/buckets.json
	echo "Creating buckets..."

	while read bucketSettings
	do
		curl -Ss http://127.0.0.1:8091/pools/default/buckets -u "$CB_USERNAME:$CB_PASSWORD" $bucketSettings
	done < <(cat /startup/buckets.json | jq -r '.[] | to_entries | map(.key + "=" + (.value | tostring)) | @sh "-d " + join(" -d ")')

	# Wait for the buckets to be healthy
	bucketCount=$(cat /startup/buckets.json | jq -r '.[].name' | wc -l)
	until [ `curl -Ss http://127.0.0.1:8091/pools/default/buckets -u $CB_USERNAME:$CB_PASSWORD | \
			 jq -r .[].nodes[].status | grep '^healthy$' | wc -l` -eq $bucketCount ];
	do
		echo "Waiting for bucket initialization..."
		sleep 1
	done

	# Run fakeit
	while read bucketName
	do
		if [ -e "/startup/$bucketName/models/" ]; then
			echo "Building data for $bucketName..."

			if [[ $CB_VERSION < "5." ]]; then
				fakeit couchbase --bucket "$bucketName" "/startup/$bucketName/models" --timeout $FAKEIT_BUCKETTIMEOUT
			else
				fakeit couchbase --bucket "$bucketName" -u "$CB_USERNAME" -p "$CB_PASSWORD" "/startup/$bucketName/models" --timeout $FAKEIT_BUCKETTIMEOUT
			fi
		fi
	done < <(cat /startup/buckets.json | jq -r '.[].name')

	while read bucketName
	do
		# Create view design documents

		if [ -e "/startup/$bucketName/views.json" ]; then
			echo "Building views on $bucketName..."

			while read designDocName
			do
				cat /startup/$bucketName/views.json |
					jq -r ".$designDocName" |
						curl -Ss -X PUT -u "$CB_USERNAME:$CB_PASSWORD" -H "Content-Type: application/json" \
							 -d @- http://127.0.0.1:8092/$bucketName/_design/$designDocName
			done < <(cat /startup/$bucketName/views.json | jq -r 'keys[]')
		fi

		# Run index scripts

		if [ -e "/startup/$bucketName/indexes.n1ql" ]; then
			echo "Building indexes on $bucketName..."

			/opt/couchbase/bin/cbq -e http://127.0.0.1:8093/ -u $CB_USERNAME -p $CB_PASSWORD -q=true -f="/startup/$bucketName/indexes.n1ql"

			# Wait for index build completion
			until [ `/opt/couchbase/bin/cbq -e http://127.0.0.1:8093/ -u $CB_USERNAME -p $CB_PASSWORD -q=true \
			         -s="SELECT COUNT(*) as unbuilt FROM system:indexes WHERE keyspace_id = '$bucket' AND state <> 'online'" | \
					 sed -n -e '/{/,$p' | \
					 jq -r '.results[].unbuilt'` -eq 0 ];
			do
				echo "Waiting for index build on $bucketName..."
				sleep 2
			done
		fi

		# Create FTS indexes

		if [ -e "/startup/$bucketName/fts" ]; then
			echo "Creating FTS indexes on $bucketName..."

			for filename in /startup/$bucketName/fts/*.json; do
				indexName=$(basename $filename .json)

				if [ "$indexName" != "aliases" ]; then
					echo "Creating FTS index $indexName..."

					# Replace the bucket name and index name
					# and strip the UUIDs from the file before creating the index

					cat $filename |
						jq -c ".name = \"$indexName\" | .sourceName = \"$bucketName\" | del(.uuid) | del(.sourceUUID)" |
						curl -Ss -X PUT -u "$CB_USERNAME:$CB_PASSWORD" -H "Content-Type: application/json" \
							 -d @- http://127.0.0.1:8094/api/index/$indexName
				fi
			done

			if [ -e "/startup/$bucketName/fts/aliases.json" ]; then
				while read aliasPair
				do
					# aliasPair will have form key=["value1","value2"], where key is alias name and values are target indexes
					# So make aliasPair an array split by =
					aliasPair=(${aliasPair//=/ })

					jsonBody=$(jq -c ".name = \"${aliasPair[0]}\"" /scripts/fts_alias_template.json)

					# Add a target for each one in the JSON array on the right side of the pair
					while read -r target; do
						jsonBody=$(echo $jsonBody | jq -c ".params.targets.$target = {}")
					done < <(echo ${aliasPair[1]} | jq -r ".[]")

					echo "Creating FTS alias ${aliasPair[0]}..."

					echo $jsonBody |
						curl -Ss -X PUT -u "$CB_USERNAME:$CB_PASSWORD" -H "Content-Type: application/json" \
							 -d @- http://127.0.0.1:8094/api/index/${aliasPair[0]}
				done < <(cat /startup/$bucketName/fts/aliases.json | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]")
			fi
		fi
	done < <(cat /startup/buckets.json | jq -r '.[].name')

	# Done
	echo "Couchbase Server initialized."
	echo "Initialized `date +"%D %T"`" > /nodestatus/initialized
else
	echo "Couchbase Server already initialized."
fi

# Wait for Couchbase Server shutdown
fg 1

