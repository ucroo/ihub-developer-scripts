#! /usr/bin/env bash

set -euo pipefail

die() {
    >&2 echo -e "error: $1"
    exit 1
}

require() {
    command -v "$1" > /dev/null || die "$1 is not in the \$PATH"
}

require python3
require sed

[ "$#" -eq "1" ] || die "usage: $(basename "$0") FLOWS_FILE"
[ -e "$1" ]      || die "cannot read file $1"

file="$1"

[ -d "./output" ] && rm -rf ./output

if python3 "$(dirname "$0")/python/export_javascript.py" "${file}" ; then
    # flows for recipes often have regex patterns like <<<THIS>>> that need to be
    # transformed into legal JavaScript. It is possible that eslint may still find
    # issues with the transformed code. For now this approach works fine.
    for jsfile in jsExport/**/*.js ; do
        sed -i '' 's/<<<//g ; s/>>>//g' "${jsfile}"
    done
else
    die "could not export Javascript"
fi
