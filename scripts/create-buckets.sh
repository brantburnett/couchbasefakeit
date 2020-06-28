#!/bin/bash

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
