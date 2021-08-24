#!/bin/sh
FRAGMENT_FILE="$1"
FRAGMENT_NAME="$2"
ENVIRONMENT="$3"
SECURE="false"

case $# in
  4)
    SECURE="$3"
    ENVIRONMENT="$4"
    ;;
  3)
    ENVIRONMENT="$3"
    ;;
  2)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the filename to this command, and the resourceId to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	exit 1
else
	curl $CURL_ARGS -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" -H "referenceId: $FRAGMENT_NAME" -H "secure: $SECURE" "$HOST/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FRAGMENT_FILE"
fi
