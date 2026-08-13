#!/bin/bash
# Regression test: a resource collection whose name contains a space must
# upload, and the scripts must report the outcome truthfully.
#
#   ./test/run-whitespace-test.sh <env>
#
# Requires ~/creds/<env>.token and ~/creds/<env>.flow for an env you are happy
# to write a throwaway collection to.
#
# Guards three bugs that shipped together:
#   1. `basename $dir` unquoted truncated the name at the space, so the
#      collection was never found and never uploaded.
#   2. A failure printed "Got unexpected HTTP response ." with no code and no
#      response body.
#   3. Exit status did not reflect the outcome, in both directions — failures
#      exited 0, and later, successes exited 1.

set -u

ENV="${1:-}"
if [ -z "$ENV" ]; then
    echo "usage: $0 <env>"
    exit 2
fi

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURE="$SCRIPTS/test/fixtures"
COLLECTION="test whitespace_widget"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/ihub-community-${ENV}"
mkdir -p "$REPO/src/main/flowResources"
cp -R "$FIXTURE/$COLLECTION" "$REPO/src/main/flowResources/"

echo "uploading '$COLLECTION' to '$ENV'"
cd "$REPO" || exit 1

output=$(PATH="$SCRIPTS:$PATH" bash "$SCRIPTS/batchUploadResourceCollections.sh" 2>&1)
status=$?

echo "$output"
echo "---------------------------------------------"

failures=0

# The name must survive word splitting all the way to the archive.
if grep -q "Uploading collection $COLLECTION" <<<"$output"; then
    echo "PASS  collection name kept its space"
else
    echo "FAIL  collection name was truncated or blank (bug 1)"
    failures=$((failures + 1))
fi

# An empty HTTP code used to render as "response ." with no diagnosis.
if grep -qE 'Got unexpected HTTP response \.|unary operator expected' <<<"$output"; then
    echo "FAIL  failure reported without a status code (bug 2)"
    failures=$((failures + 1))
fi

# Exit status must match what actually happened.
if grep -q '"message":"success"' <<<"$output"; then
    if [ "$status" -eq 0 ]; then
        echo "PASS  upload succeeded and exit status is 0"
    else
        echo "FAIL  upload succeeded but exit status was $status (bug 3)"
        failures=$((failures + 1))
    fi
else
    if [ "$status" -ne 0 ]; then
        echo "PASS  upload failed and exit status is non-zero"
        echo "      (not a successful upload - check the token for '$ENV')"
    else
        echo "FAIL  upload did not succeed but exit status was 0 (bug 3)"
        failures=$((failures + 1))
    fi
fi

echo "---------------------------------------------"
if [ "$failures" -eq 0 ]; then
    echo "OK"
else
    echo "$failures check(s) failed"
fi

echo
echo "Remove the uploaded collection with:"
echo "  deleteResourceCollection.sh '$COLLECTION' $ENV"

exit "$failures"
