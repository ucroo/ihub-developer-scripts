#! /bin/bash

set -eou pipefail

die() {
    >&2 echo "$*"
    exit 1
}

require() {
    command -v "$1" > /dev/null || die "$1 is not in the \$PATH"
}

if [ "$#" -lt "2" ] ; then
    die "usage: $(basename "$0") SERVER ENTITY_FILE.."
fi

server=$1
shift

# Make sure that scripts we call are in the PATH.
require uploadFlow.sh
require uploadResourceCollection.sh
require uploadTrigger.sh
require uploadSharedConfig.sh
require uploadRecipe.sh

detectType() {
  fileName="$1"
  absolutePath=$(readlink -f "$fileName")

  if [[ "${absolutePath}" =~ flows/ ]] ; then
    echo "flow"
  elif [[ "${absolutePath}" =~ flowResources/ ]] ; then
    echo "resource"
  elif [[ "${absolutePath}" =~ triggerers/ ]] ; then
    echo "trigger"
  elif [[ "${absolutePath}" =~ sharedConfig/ ]] ; then
    echo "config"
  elif [[ "$(pwd)/${absolutePath}" =~ recipe ]] ; then
    echo "recipe"
  else
    echo "unknown"
  fi
}

uploadFlow() {
  entity="$1"
  pushd "$(dirname "${entity}")/../../.." > /dev/null || exit 1
  uploadFlow.sh "$(basename "${entity%%.json}")" "${server}" 
  popd > /dev/null
}

uploadResource() {
  entity="$1"
  pushd "$(dirname "${entity}")" > /dev/null || exit 1
  uploadResourceCollection.sh "$(basename "${entity}")" "${server}"
  popd > /dev/null
}

uploadTrigger() {
  entity="$1"
  pushd "$(dirname "${entity}")/../../.." > /dev/null || exit 1
  uploadTrigger.sh "$(basename "${entity%%.json}")" "${server}"
  popd > /dev/null
}

uploadSharedConfig() {
  entity="$1"
  pushd "$(dirname "${entity}")/../../.." > /dev/null || exit 1
  uploadSharedConfig.sh "$(basename "${entity%%.json}")" "${server}"
  popd > /dev/null
}

uploadRecipe() {
  entity="$1"
  pushd "$(dirname "${entity}")" > /dev/null || exit 1
  uploadRecipe.sh "$(basename "${entity}")" "${server}"
  popd > /dev/null
}

for entity in "$@" ; do
  echo "Uploading: ${entity} ..."

  if [ ! -r "${entity}" ] ; then
      >&2 echo "can't read file: ${entity}"
      continue
  fi

  type=$(detectType "$entity")

  case "$type" in

    "flow")
      uploadFlow "${entity}"
      ;;

    "config")
      uploadSharedConfig "${entity}"
      ;;

    "recipe")
      uploadRecipe "${entity}"
      ;;

    "trigger")
      uploadTrigger "${entity}"
      ;;

    "resource")
      uploadResource "${entity}"
      ;;

    *)
      >&2 echo "unknown file type: ${entity}"
      ;;

  esac
  echo
done

