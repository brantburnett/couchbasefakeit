#!/bin/bash

set -o pipefail

function log_error() {
  echo $1 >> /nodestatus/errors
  >&2 echo $1

  # There's no point in waiting for buckets that aren't going to exist, so short circuit
  exit 1
}

# Create buckets defined in /startup/buckets.json
echo "Creating buckets..."

bucketSettingsList=$(cat /startup/buckets.json | jq -r '.[] | to_entries | map(.key + "=" + (.value | tostring)) | @sh "-d " + join(" -d ")') ||
  log_error "Error parsing buckets.json"

echo $bucketSettingsList | {
  while read bucketSettings
  do
    curl -Ss http://127.0.0.1:8091/pools/default/buckets -u "$CB_USERNAME:$CB_PASSWORD" $bucketSettings ||
      log_error "Failed to create bucket $bucketSettings"
  done
}

# Wait for the buckets to be healthy
bucketCount=$(cat /startup/buckets.json | jq -r '.[].name' | wc -l)
counter=0
until [ `curl -Ss http://127.0.0.1:8091/pools/default/buckets -u $CB_USERNAME:$CB_PASSWORD | \
         jq -r .[].nodes[].status | grep '^healthy$' | wc -l` -eq $bucketCount ];
do
  counter=$[$counter + 1]
  if [[ $counter >= 60 ]]; then
    log_error "Timeout waiting for bucket initialization"
  fi

  echo "Waiting for bucket initialization..."
  sleep 1
done
