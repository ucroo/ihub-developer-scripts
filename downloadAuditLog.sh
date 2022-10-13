#!/usr/bin/env bash

# Useful queries that can be run on the file that this script generates:
#
# Select all audit log events that were POSTs for flows that contain 'orchestration@'
# jq '[.[]
#     | select(.audited.method == "POST")
#     | select(.audited.path == "repository/flows")
#     | select(.audited.body.bodyText | contains("orchestration@"))
#     ]' <json-file.json>
#
# Select all audit log events that were DELETEs for flows that contain 'orchestration@'
jq '[.[]
    | select(.audited.method == "DELETE")
    | select(.audited.path == "repository/flows")
    | select(.audited.body.bodyText | contains("orchestration@"))
    ]' <json-file.json>

set -euo pipefail

die() {
    >&2 echo -e "error: $1"
    exit 1
}

require() {
    command -v "$1" > /dev/null || die "$1 is not in the \$PATH"
}

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

tempDir="$(mktemp -d)"
trap 'rm -rf -- "$tempDir"' EXIT
tempFile="${tempDir}/logFile.json"

function downloadAuditLog {
    output=$(curl "${HOST}/repository/auditLogs" \
                  -w "\nStatus: %{http_code}"          \
                  -H "flow-token: ${FLOW_TOKEN}"       \
                  -H "Accept: application/json"        \
                  --no-progress-meter)
    if [[ "${output}" =~ "Status: 200" ]] ; then
        if echo "${output}" | grep -v "Status: "| jq empty >& /dev/null ; then
            echo "${output}" | grep -v "Status: " > "${tempFile}"
        else
            >&2 echo "server did not return valid JSON.  Is your token valid?"
            return 1
        fi
    else
        >&2 echo "request failed: ${output}"
    fi
}

require jq
downloadAuditLog

jq 'sort_by(.when)
    | . []

    | .audited.body.base64          |= if . then @base64d else . end
    | .audited.responseBody.base64  |= if . then @base64d else . end

    | .audited.body["bodyText"]          = .audited.body.base64
    | .audited.responseBody["bodyText"]  = .audited.responseBody.base64

    | .when |= (./1000 | todateiso8601)

    | del(.audited.body.base64, .audited.responseBody.base64)

    ' \
    "$tempFile" | jq -s > "${environment}-audit-log.json"
