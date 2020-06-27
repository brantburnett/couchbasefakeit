#!/bin/bash
set -m

/entrypoint.sh couchbase-server &

if [ ! -e "/nodestatus/initialized" ] ; then
  export CB_VERSION=$(cat /opt/couchbase/VERSION.txt | grep -o "^[0-9]*\.[0-9]*\.[0-9]*")
  echo "CB_VERSION=$CB_VERSION"

  scriptPath=$(dirname $(realpath $0))

  $scriptPath/init-node.sh
  $scriptPath/wait-for-services.sh
  $scriptPath/create-buckets.sh
  $scriptPath/run-fakeit.sh

  while read bucketName
  do
    $scriptPath/create-views.sh $bucketName
    $scriptPath/create-n1ql-indexes.sh $bucketName
    $scriptPath/create-fts-indexes.sh $bucketName
  done < <(cat /startup/buckets.json | jq -r '.[].name')

  # Done
  echo "Couchbase Server initialized."
  echo "Initialized `date +"%D %T"`" > /nodestatus/initialized
else
  echo "Couchbase Server already initialized."
fi

# Wait for Couchbase Server shutdown
fg 1

