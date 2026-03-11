#!/bin/bash

# This bash script is used to batch upload resource collections to the iHub server. It iterates through  the directories in the src/main/flowResources directory and uploads each resource collection to the server.

# Assumes that you are in the root of the community directory and that it's named like /ihub-community-<COMMUNITY_NAME>
community=$(basename "$(pwd)" | grep -o '[^-]*$')

env="prod"
collections=()
collectionsSpecified=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            env="$2"
            shift 2
            ;;
        --collections)
            collectionsSpecified=true
            shift
            while [[ $# -gt 0 && ! $1 == --* ]]; do
                collections+=("$1")
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$collectionsSpecified" = true ] && [ ${#collections[@]} -eq 0 ]; then
    echo "Error: --collections was specified but no collections were provided. Check that your command substitution is producing output."
    exit 1
fi

cd ./src/main/flowResources || exit

if [ ${#collections[@]} -eq 0 ]; then
    for dir in ./*; do
        [ -d "$dir" ] && collections+=("$(basename "$dir")")
    done
fi

errorReport=""
for resource in "${collections[@]}"; do
    if [ -d "$resource" ]; then
        echo -e "\nUploading collection $resource\n"
        if [ "$env" == "prod" ]; then
            uploadEnv="$community"
        else
            uploadEnv="$env-$community"
        fi
        if ! uploadResourceCollection.sh "$resource" "$uploadEnv" ; then
            errorReport+="$resource failed to upload.\n"
        fi
    else
        errorReport+="$resource not found in flowResources.\n"
    fi
done

if [ -n "$errorReport" ]; then
    echo -e "Some resources failed to upload:\n$errorReport"
else
    echo "All resource collections uploaded successfully!"
fi