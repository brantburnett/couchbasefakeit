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
            --bucket "$bucketName" \
            "/startup/$bucketName/models"
        elif [[ $CB_VERSION > "7." ]]; then
          # to ensure the scopes and collections that were just created
          # in prior steps, pause for a few seconds before continuing
          sleep 5

          # Create an array to hold the paths that have already been processed
          # so that we only handle each path once.
          declare -a processedPaths

          # Loop through the scopes and collections that were created and insert
          # fake data into the appropriate scope and collection
          while read scope; do
            while read collection; do
              echo "Scope to use: $scope -- Collection to use: $collection..."

              runFakeit=false

              # Determine the directory structure so we can adjust the values needed
              # by FakeIt when storing data for each model
              if [[ -d "/startup/$bucketName/models/$scope/$collection" ]]; then
                scopeName=$scope
                collectionName=$collection
                modelsPath="/startup/$bucketName/models/$scope/$collection/*.yaml"
                runFakeit=true
              elif [[ -d "/startup/$bucketName/models/$scope" ]]; then
                scopeName=$scope
                collectionName="default"
                modelsPath="/startup/$bucketName/models/$scope/*.yaml"
                runFakeit=true
              fi

              # Check to see if the path exists already in the array
              pathAlreadyProcessed=false
              for path in "${processedPaths[@]}"; do
                if [[ "$path" == "$modelsPath" ]] ; then
                  pathAlreadyProcessed=true
                  break
                fi
              done

              # Check to see if we already processed the model directory and if we need
              # to run fakeit for the scope and collection being processed
              if [ "$pathAlreadyProcessed" == false ] && [ "$runFakeit" == true ]; then
                echo "About to run fakeit..."
                /scripts/node_modules/.bin/fakeit couchbase \
                  -b "$bucketName" -u "$CB_USERNAME" -p "$CB_PASSWORD" \
                  --scopeName "$scopeName" --collectionName="$collectionName" \
                  $modelsPath

                # Add the model path to an array so that we only process each folder once
                processedPaths+=("$modelsPath")
              fi

            done < <(cat /startup/$bucketName/collections.json | jq -r ".scopes.$scope | .collections | .[]")
          done < <(cat /startup/$bucketName/collections.json | jq -r '.scopes | keys[]')

          # Process any models not associated with a scope or collection...
          yamlFiles=$(find /startup/$bucketName/models -type f -name "*.yaml")
          if [[ ( -n yamlFiles ) ]]; then
            echo "About to run fakeit..."
            /scripts/node_modules/.bin/fakeit couchbase \
              -b "$bucketName" -u "$CB_USERNAME" -p "$CB_PASSWORD" \
              --scopeName "_default" --collectionName="_default" \
              "/startup/$bucketName/models/*.yaml"
          fi
        else
          /scripts/node_modules/.bin/fakeit couchbase \
            --bucket "$bucketName" -u "$CB_USERNAME" -p "$CB_PASSWORD" \
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
