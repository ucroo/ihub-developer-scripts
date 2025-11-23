#!/usr/bin/env bash

set -euo pipefail

die() {
    >&2 echo -e "error: $1"
    exit 1
}

require() {
    command -v "$1" > /dev/null || die "$1 is not in the \$PATH"
}

require python3
require curl
require jq

CURL_ARGS="${CURL_ARGS:-}"

case $# in
    0)
        environment="local"
        ;;
    1)
        environment="$1"
        ;;
    *)
        echo "usage: $(basename "$0") [ENV]"
        exit 1
        ;;
esac

source setEnvForUpload.sh $environment

mkdir -p src/main/{flows,flowResources,sharedConfig,triggerers,patchSets}


function downloadJsonFile {
    entityType=$1
    outputDirectory=${2:-$1}
    parameters=${3:-}
    output=$(curl $CURL_ARGS "${HOST}/ihub-viewer/repository/${entityType}${parameters}" \
                -w "\nFLOW_RESPONSE_STATUS: %{http_code}"                       \
                -H "flow-token: ${FLOW_TOKEN}"                    \
                -H "Accept: application/json"                     \
                --no-progress-meter)

    if [[ "${output}" =~ "FLOW_RESPONSE_STATUS: 200" ]] ; then
        outputFile="./src/main/${outputDirectory}/${environment}.json"
        if echo "${output}" | grep -v "FLOW_RESPONSE_STATUS: "| jq empty >& /dev/null ; then
            echo "${output}" | grep -v "FLOW_RESPONSE_STATUS: " > "${outputFile}"
            filtered=$(jq 'del(.[].metadata, .[].referencedBy)' "${outputFile}")
            echo "${filtered}" > "${outputFile}"
        else
            echo "${output}"
            >&2 echo "server did not return valid JSON.  Is your token valid?"
            return 1
        fi
    else
        >&2 echo "request failed: ${output}"
    fi
}

function downloadZipFile {
    entityType=$1
    outputDirectory=${2:-$1}
    outputFile="./src/main/${outputDirectory}/${environment}.zip"
    if curl $CURL_ARGS "${HOST}/ihub-viewer/repository/${entityType}?format=zip" \
                  -H "flow-token: ${FLOW_TOKEN}"          \
                  -H "Accept: application/zip"            \
                  --no-progress-meter                     \
                  > "${outputFile}" ; then
        if [ -r "${outputFile}" ] ; then
            unzip -o "${outputFile}" -d "./src/main/${outputDirectory}/" > /dev/null || true
            rm "${outputFile}"
            # Use jq to format the JSON files that were in the zip file.
            while IFS= read -r -d '' jsonFile ; do
                filtered=$(jq 'del(.metadata)' "${jsonFile}")
                echo "${filtered}" > "${jsonFile}"
                cat <<< "$(jq < "${jsonFile}")" > "${jsonFile}"
            done < <(find "./src/main/${outputDirectory}" -iname '*.json' -print0)
        fi
   fi
}

#                Flow Route            Directory        Query String Parameters
#                -------------------   ------------     ---------------------------
downloadJsonFile flows                 flows
downloadJsonFile sharedConfig          sharedConfig     '?encrypted_only=true'
downloadJsonFile flowTriggerers        triggerers
downloadJsonFile patchSets             patchSets
downloadZipFile  resourceCollections   flowResources

# Format the JavaScript in the flow JSON file.
python3 "$(dirname "$0")/python/format_json.py" "./src/main/flows/${environment}.json"
