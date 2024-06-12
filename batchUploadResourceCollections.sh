#!/bin/bash

# This bash script is used to batch upload resource collections to the iHub server. It iterates through 

# Assumes that you are in the root of the community directory and that it's named like /ihub-community-<COMMUNITY_NAME>
community=$(basename "$(pwd)" | grep -o '[^-]*$') 

cd ./src/main/flowResources || exit

for dir in ./*; do
    if [ -d "$dir" ]; then
        resource=$(basename $dir)
        echo ""
        echo "Uploading collection $resource"
        uploadResourceCollection.sh "$resource" "$community"
        echo ""
    fi
done

echo "Resource collections uploaded successfully!"