#!/bin/bash

echo "Initializing Couchbase Server $CB_VERSION..."

if [[ $CB_VERSION > "5." && $CB_INDEXSTORAGE == "forestdb" ]]; then
  # Couchbase 5.0 and later doesn't support forestdb, switch to plasma instead
  export CB_INDEXSTORAGE=plasma

  echo "Switching from forestdb to plasma for index storage."
fi

sleep 5

# Configure cluster, first request may need more time so retry
for attempt in $(seq 60)
do
  echo "Cluster name: $CB_CLUSTER_NAME"

  # Change the name of the cluster if the user provided a cluster name
  if [[ ! -z $CB_CLUSTER_NAME ]]; then
    echo "Changing cluster name to $CB_CLUSTER_NAME..."
    curl -Ss -X POST http://127.0.0.1:8091/pools/default -d clusterName=$CB_CLUSTER_NAME && echo
  fi

  curl -Ss -X POST http://127.0.0.1:8091/pools/default \
      -d memoryQuota=$CB_DATARAM \
      -d indexMemoryQuota=$CB_INDEXRAM \
      -d ftsMemoryQuota=$CB_SEARCHRAM \
      -d cbasMemoryQuota=$CB_ANALYTICSRAM \
      -d eventingMemoryQuota=$CB_EVENTINGRAM \
    && echo \
    && break

  echo "Waiting for Couchbase startup..."
  sleep 1
done

curl -Ss http://127.0.0.1:8091/node/controller/setupServices -d services=${CB_SERVICES//,/%2C} && echo
curl -Ss http://127.0.0.1:8091/settings/indexes -d storageMode=$CB_INDEXSTORAGE && echo
curl -Ss http://127.0.0.1:8091/settings/web -d port=8091 -d "username=$CB_USERNAME" -d "password=$CB_PASSWORD" && echo
