#! /bin/bash
# checkConsoleFilters -- examines a file downloaded from <BASE_URL>/ihub-viewer/repository/flows
# to see if its consoleFilters are configured correctly.
#
# Note: this script is inefficient due to its repeated parsing of the JSON file but
#       it is fast enough to be usable.

set -euo pipefail

die() {
    echo "$*"
    exit 1
}

[ "$#" = "1" ]            || die "usage: $(basename "$0") FILE"
[ -r "$1" ]               || die "error: $1 is not readable"
command -v jq > /dev/null || die "error: jq must be installed"
file=$1

indent()          { sed 's/^/  /'; }
valueNotEqualTo() { compareValue "$1" "!=" "$2"; }
valueEqualTo()    { compareValue "$1" "==" "$2"; }

compareValue() {
    property=$1
    operator=$2
    value=$3
    output=$(jq -r ".[] | {
        name,
        ${property}: .consoleFilter.${property}
    } | select (
        .${property} ${operator} ${value}
    ) | select(.name | ascii_downcase | contains(\"test\") | not) | .name" "$file")
    if [ -n "${output}" ] ; then
        echo "flows where $property $operator $value:"
        echo "${output}" | indent
    fi
}

main() {
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

main
