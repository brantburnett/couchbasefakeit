#!/bin/bash

# Create rbac users

if [ -e "/startup/rbac-users.json" ]; then
  while read rbacSettings
  do
    rbacBucketName=$(echo $rbacSettings | jq -r '.["bucket"]')
    rbacName=$(echo $rbacSettings | jq -r '.["rbacName"]')
    rbacUsername=$(echo $rbacSettings | jq -r '.["rbacUsername"]')
    rbacPassword=$(echo $rbacSettings | jq -r '.["rbacPassword"]')
    rbacRoles=$(echo $rbacSettings | jq -r '.roles | join(",")')

    echo "Bucket Name = $rbacBucketName"

    if [[ ! -z $rbacBucketName ]]; then
      echo "Bucket match found, creating RBAC users on $rbacBucketName..."

      curl -Ss -X PUT http://127.0.0.1:8091/settings/rbac/users/local/$rbacUsername \
        -u $CB_USERNAME:$CB_PASSWORD \
        -d password=$rbacPassword \
        -d name="$rbacName" \
        -d roles=$rbacRoles && echo
    fi
  done < <(cat /startup/rbac-users.json | jq -c '.[]')
fi
