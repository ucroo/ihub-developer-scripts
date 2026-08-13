#!/bin/bash

FLOW="$1"
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
	http_response=$(curl $CURL_ARGS -s -o uploadSharedConfigResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FLOW.json")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadSharedConfigResponse.txt"; then
  _status=1
else
  cat uploadSharedConfigResponse.txt
fi

[ -e uploadSharedConfigResponse.txt ] && rm uploadSharedConfigResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
