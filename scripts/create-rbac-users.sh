#!/bin/bash

bucketName=$1

# Create rbac users

if [ -e "/startup/$bucketName/rbac-users.json" ]; then
  echo "Creating users on $bucketName..."

  while read rbacSettings
  do
    rbacBucketName=$(echo $rbacSettings | jq -r '.["bucket"]')
    rbacName=$(echo $rbacSettings | jq -r '.["rbacName"]')
    rbacUsername=$(echo $rbacSettings | jq -r '.["rbacUsername"]')
    rbacPassword=$(echo $rbacSettings | jq -r '.["rbacPassword"]')
    rbacRoles=$(echo $rbacSettings | jq -r '.roles | join(",")')

    if [[ $rbacBucketName = $bucketName ]]; then
      echo "Bucket match found, creating RBAC users..."

      curl -Ss -X PUT http://127.0.0.1:8091/settings/rbac/users/local/$rbacUsername \
        -u $CB_USERNAME:$CB_PASSWORD \
        -d password=$rbacPassword \
        -d name="$rbacName" \
        -d roles=$rbacRoles
    fi
  done < <(cat /startup/$bucketName/rbac-users.json | jq -c '.[]')
fi
