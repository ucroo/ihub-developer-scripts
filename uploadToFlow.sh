#! /bin/bash

die() {
    >&2 echo "$*"
    exit 1
}

require() {
    command -v "$1" > /dev/null || die "$1 is not in the \$PATH"
}

if [ "$#" -ne "2" ] ; then
    die "usage: $(basename "$0") SERVER ENTITY_FILE"
fi

server=$1
entityFile=$2

# Make sure that scripts we call are in the PATH.
require uploadFlow.sh
require uploadResourceCollection.sh
require uploadTrigger.sh
require uploadSharedConfig.sh
require uploadRecipe.sh

if [ ! -r "${entityFile}" ] ; then
    die "can't read file: ${entityFile}"
fi

if [[ "${entityFile}" =~ flows/ ]] ; then
    cd "$(dirname "${entityFile}")/../../.." || exit 1
    uploadFlow.sh "$(basename "${entityFile%%.json}")" "${server}"

elif [[ "${entityFile}" =~ flowResources/ ]] ; then
    cd "$(dirname "${entityFile}")" || exit 1
    uploadResourceCollection.sh "$(basename "${entityFile}")" "${server}"

elif [[ "${entityFile}" =~ triggerers/ ]] ; then
    cd "$(dirname "${entityFile}")/../../.." || exit 1
    uploadTrigger.sh "$(basename "${entityFile%%.json}")" "${server}"

elif [[ "${entityFile}" =~ sharedConfig/ ]] ; then
    cd "$(dirname "${entityFile}")/../../.." || exit 1
    uploadSharedConfig.sh "$(basename "${entityFile%%.json}")" "${server}"

elif [[ "$(pwd)/${entityFile}" =~ recipe ]] ; then
    cd "$(dirname "${entityFile}")" || exit 1
    uploadRecipe.sh "$(basename "${entityFile}")" "${server}"
else
    die "don't know what to upload."
fi
