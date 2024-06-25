#!/bin/bash

school=$(basename "$(pwd)" | grep -o '[^-]*$') 
env=$1
oldUrl=$2
newUrl=$3


findAndReplace() {
    # If the env is QA, then fileName is prefixed with qa 
    filenamePrefix=""
    if [ "$env" == "qa" ]; then
        filenamePrefix="qa-"
    fi

    find . -type f -name "$filenamePrefix*.json" -exec sed -i "s/$oldUrl/$newUrl/g" {} +
    
}


if [ -z "$env" ] || [ -z "$oldUrl" ] || [ -z "$newUrl" ]; then
  echo "Usage: $0 <environment> <oldUrl> <newUrl>"
  exit 1
fi

if { [ ! "$env" == "production" ] && [ ! "$env" == "qa" ]; }; then
  echo "Invalid environment: $env"
  exit 1
fi

downloadFlowEntities.sh "$school"

# Replace the old URL with the new URL in the downloaded JSON files
awk -v oldUrl="$oldUrl" -v newUrl="$newUrl" '{gsub(oldUrl, newUrl)}1'

# Upload the resource collections
batchUploadResourceCollections.sh


