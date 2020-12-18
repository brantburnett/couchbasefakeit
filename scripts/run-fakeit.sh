#!/bin/bash

DATABASE_URL='couchbase://127.0.0.1'

scope="_default"
if [[ -n "$FAKE_DATA_SCOPE" ]]; then
  scope=$FAKE_DATA_SCOPE
fi

collectionField='_default'
if [[ -n "$FAKE_DATA_COLLECTION_FIELD" ]]; then
  collectionField="%$FAKE_DATA_COLLECTION_FIELD%"
fi

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
        elif [[ $CB_VERSION > "6." ]]; then
          /scripts/node_modules/.bin/fakeit directory --format json \
            /cbdata \
            "/startup/$bucketName/models/*"

          sleep 5

          jq -s '.' /cbdata/*.json > /cbdata/all_documents.json

          sleep 5

          cbimport json -c $DATABASE_URL -u "$CB_USERNAME" -p "$CB_PASSWORD" -b $bucketName -f list \
            --no-ssl-verify -d file:///cbdata/all_documents.json \
            --scope-collection-exp $scope.$collectionField \
            --generate-key %id%
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
