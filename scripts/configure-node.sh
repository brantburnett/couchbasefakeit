#!/bin/bash
set -m

EXIT_CODE=0

function log_error() {
  echo $1 >> /nodestatus/errors
  >&2 echo $1

  EXIT_CODE=1
}

function check_error() {
  if [[ $EXIT_CODE != "0" && $CB_STOPONERROR != "0" ]]; then
    # Exiting here should cause the Docker container to stop, including Couchbase Server
    exit $EXIT_CODE
  fi
}

/entrypoint.sh couchbase-server &

if [ ! -e "/nodestatus/initialized" ] ; then
  export CB_VERSION=$(cat /opt/couchbase/VERSION.txt | grep -o "^[0-9]*\.[0-9]*\.[0-9]*")
  echo "CB_VERSION=$CB_VERSION"

  scriptPath=$(dirname $(realpath $0))

  $scriptPath/init-node.sh || log_error "Unable to initialize node"
  check_error

  $scriptPath/wait-for-services.sh || log_error "Error waiting for services"
  check_error

  $scriptPath/create-buckets.sh || log_error "Error creating buckets"
  check_error

  $scriptPath/run-fakeit.sh || log_error "Error creating FakeIt models"
  check_error

  while read bucketName
  do
    $scriptPath/create-views.sh $bucketName || log_error "Error creating views for $bucketName"
    check_error

    $scriptPath/create-n1ql-indexes.sh $bucketName || log_error "Error creating N1QL indexes for $bucketName"
    check_error

    $scriptPath/create-fts-indexes.sh $bucketName || log_error "Error creating FTS indexes for $bucketName"
    check_error
  done < <(cat /startup/buckets.json | jq -r '.[].name')

  $scriptPath/create-events.sh || log_error "Error creating events"
  check_error

  if [ $EXIT_CODE -eq 0 ]; then
    echo "Couchbase Server initialized."
  else
    echo "Couchbase Server initialized with errors."
  fi

  echo "Initialized `date +"%D %T"`" > /nodestatus/initialized
else
  echo "Couchbase Server already initialized."
fi

# Wait for Couchbase Server shutdown
fg 1
