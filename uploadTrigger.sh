#!/bin/sh
SOURCE_FILE="$1"
ENVIRONMENT="$2"

case $# in
  2)
    ENVIRONMENT="$2"
    ;;
  1)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the flowName to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	curl $CURL_ARGS -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/flowTriggerers" --data-binary "@src/main/triggerers/$SOURCE_FILE.json"
fi
