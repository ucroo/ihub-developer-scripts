#!/bin/bash

# This bash script is used to batch upload resource collections to the iHub server. It iterates through  the directories in the src/main/flowResources directory and uploads each resource collection to the server.

# Assumes that you are in the root of the community directory and that it's named like /ihub-community-<COMMUNITY_NAME>
community=$(basename "$(pwd)" | grep -o '[^-]*$') 

cd ./src/main/flowResources || exit

errorReport=""
for dir in ./*; do
    if [ -d "$dir" ]; then
        echo -e "\nUploading collection $resource\n"
  
        resource=$(basename $dir)
        if ! uploadResourceCollection.sh "$resource" "$community" ; then
            errorReport+="$resource failed to upload.\n"
        fi

    fi
done

cd ../../..

if [ -n "$errorReport" ]; then
    echo -e "Some resources failed to upload:\n$errorReport"
else
    echo "All resource collections uploaded successfully!"
fi