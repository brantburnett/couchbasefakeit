#!/bin/bash

# Run fakeit
while read bucketName
do
  if [ -e "/startup/$bucketName/models/" ]; then
    echo "Building data for $bucketName..."

    triesLeft=5
    # execute the code block at least once
    while true;
    do
      # Try and create a document to see if the bucket is initialized, try again if it errored
      # If the bucket isn't initialized fakeit will error
      if node /scripts/is-the-bucket-ready.js $bucketName $CB_USERNAME $CB_PASSWORD $CB_VERSION; then
        if [[ $CB_VERSION < "5." ]]; then
          /scripts/node_modules/.bin/fakeit couchbase \
            --bucket "$bucketName" --timeout $FAKEIT_BUCKETTIMEOUT \
            "/startup/$bucketName/models"
        else
          /scripts/node_modules/.bin/fakeit couchbase \
            --bucket "$bucketName" -u "$CB_USERNAME" -p "$CB_PASSWORD" --timeout $FAKEIT_BUCKETTIMEOUT \
            "/startup/$bucketName/models"
        fi
        break
      else
        if (( $triesLeft > 0)); then
            echo "Trying again"

            # Give the bucket a little more time to be ready
            sleep 3
        else
          echo "Data wasn't built"
        fi
        ((triesLeft--))

        (( $triesLeft >= 0 )) || break
      fi
    done
  fi
done < <(cat /startup/buckets.json | jq -r '.[].name')
