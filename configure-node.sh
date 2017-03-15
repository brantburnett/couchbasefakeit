#!/bin/bash
set -m

/entrypoint.sh couchbase-server &

if [ ! -e "/node-initialized" ] ; then
	echo "Initializing Couchbase Server..."
	
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
			sleep 2
		done

		# Query service still needs a bit to finish startup after ping succeeds
		sleep 5
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
			
			fakeit couchbase --bucket "$bucketName" "/startup/$bucketName/models"
		fi
	done < <(cat /startup/buckets.json | jq -r '.[].name')
	
	# Run index scripts
	while read bucketName
	do
		if [ -e "/startup/$bucketName/indexes.n1ql" ]; then
			echo "Building indexes on $bucketName..."
			
			/opt/couchbase/bin/cbq -q=true -f="/startup/$bucketName/indexes.n1ql"

			# Wait for index build completion
			until [ `/opt/couchbase/bin/cbq -q=true -s="SELECT COUNT(*) as unbuilt FROM system:indexes WHERE keyspace_id = '$bucket' AND state <> 'online'" | \
					 sed -n -e '/{/,$p' | \
					 jq -r '.results[].unbuilt'` -eq 0 ];
			do
				echo "Waiting for index build on $bucketName..."
				sleep 2
			done
		fi
	done < <(cat /startup/buckets.json | jq -r '.[].name')
	
	# Done
	echo "Couchbase Server initialized."
	echo "Initialized `date +"%D %T"`" > /node-initialized
else
	echo "Couchbase Server already initialized."
fi

# Wait for Couchbase Server shutdown
fg 1

