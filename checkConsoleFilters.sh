#! /bin/bash
# checkConsoleFilters -- examines a file downloaded from <BASE_URL>/repository/flows
# to see if its consoleFilters are configured correctly.
#
# Note: this script is inefficient due to its repeated parsing of the JSON file but
#       it is fast enough to be usable.

set -euo pipefail

indent()          { sed 's/^/  /'; }
valueNotEqualTo() { compareValue "$1" "!=" "$2"; }
valueEqualTo()    { compareValue "$1" "==" "$2"; }

die() {
    echo "$*"
    exit 1
}

compareValue() {
    property=$1
    operator=$2
    value=$3
    output=$(jq -r ".[] | {
        name,
        ${property}: .consoleFilter.${property}
    } | select (
        .${property} ${operator} ${value}
    ) | select(.name | ascii_downcase | contains(\"test\") | not) | .name" "$flowFile")
    if [ -n "${output}" ] ; then
        echo "flows where $property $operator $value:"
        echo "${output}" | indent
    fi
}

[ "$#" = "1" ]            || die "usage: $(basename "$0") ENVIRONMENT"
command -v jq > /dev/null || die "error: jq must be installed"

function downloadJsonFile {
    output=$(curl "${HOST}/repository/flows"        \
                  -w "\nStatus: %{http_code}"       \
                  -H "flow-token: ${FLOW_TOKEN}"    \
                  -H "Accept: application/json"     \
                  --no-progress-meter)
    if [[ "${output}" =~ "Status: 200" ]] ; then
        if echo "${output}" | grep -v "Status: "| jq empty >& /dev/null ; then
            echo "${output}" | grep -v "Status: " > "${flowFile}"
        else
            >&2 echo "server did not return valid JSON.  Is your token valid?"
            return 1
        fi
    else
        >&2 echo "request failed: ${output}"
    fi
}


main() {
    if [ -f "$1" ] ; then
        flowFile="$1"
    else
        # Create temp file to store flow JSON data in and ensure
        # that it will be cleaned up when the script exits
        flowFile=$(mktemp)
        #trap "rm -f $flowFile" 0 2 3 15
        echo $flowFile

        # Set up the FLOW token
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

        downloadJsonFile
    fi

    # Print out console filters that match the following
    # undesirable conditions.
    valueNotEqualTo error true
    valueEqualTo debug true
    valueEqualTo info true
    valueEqualTo warn true
    valueEqualTo other true
    valueEqualTo synchronous true
    valueEqualTo forceStreams true
    valueEqualTo sendToCentralReporter true
    valueEqualTo summarizeToCentral true
    valueEqualTo saveStateToDb true
    valueEqualTo consoleMessageSynchronous true
    valueEqualTo logPayload true
    valueEqualTo logStart true
    valueEqualTo logMiddle true
    valueEqualTo logEnd true
}

main $*
