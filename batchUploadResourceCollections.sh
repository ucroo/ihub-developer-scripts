#!/bin/bash

# This bash script is used to batch upload resource collections to the iHub server. It iterates through  the directories in the src/main/flowResources directory and uploads each resource collection to the server.

# Assumes that you are in the root of the community directory and that it's named like /ihub-community-<COMMUNITY_NAME>
. "$(dirname "$0")/commonFunctions.sh"

[[ -z "$1" ]] && die "Usage: $0 <production|qa>"
environment="$1"


environmentPrefix=""
if [ "$environment" == "qa" ]; then
    environmentPrefix="qa-"
fi

community="${environmentPrefix}$(basename "$(pwd)" | grep -o '[^-]*$')"

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

if [ -n "$errorReport" ]; then
    echo -e "Some resources failed to upload:\n$errorReport"
else
    echo "All resource collections uploaded successfully!"
fi