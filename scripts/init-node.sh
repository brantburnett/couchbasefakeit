#!/bin/bash

EXIT_CODE=0

function log_error() {
  echo $1 >> /nodestatus/errors
  >&2 echo $1

  EXIT_CODE=1
}

function curl_with_test() {
  local out=$(curl -Ss -w '\nstatus_code=%{http_code}\n' $@)
  local status_code=$(echo ${out} | grep status_code | awk -F"=" '{print $2}')

  if [[ $status_code -ne "200" ]]; then
    echo $out
    return 1
  else
    return 0
  fi
}

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
  curl -s -o /dev/null http://127.0.0.1:8091/pools/default -d memoryQuota=$CB_DATARAM -d indexMemoryQuota=$CB_INDEXRAM -d ftsMemoryQuota=$CB_SEARCHRAM \
    && INITIALIZED=1 \
    && break

  echo "Waiting for Couchbase startup..."
  sleep 1
done

if [[ $INITIALIZED != "1" ]]; then
  log_error "Couchbase not started within timeout"
  exit $EXIT_CODE
fi

curl_with_test http://127.0.0.1:8091/node/controller/setupServices -d services=${CB_SERVICES//,/%2C} ||
  log_error "Error configuring services"
curl_with_test http://127.0.0.1:8091/settings/indexes -d storageMode=$CB_INDEXSTORAGE ||
  log_error "Error configuring index storage"
curl_with_test http://127.0.0.1:8091/settings/web -d port=8091 -d "username=$CB_USERNAME" -d "password=$CB_PASSWORD" ||
  log_error "Error configuring authentication"

exit $EXIT_CODE
