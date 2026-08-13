#!/bin/bash

TARGET="$1"
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
    exit 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	exit 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadFlowResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/patchSets" --data-binary "@src/main/patchSets/$TARGET.json")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadFlowResponse.txt"; then
  _status=1
else
  cat uploadFlowResponse.txt
fi

[ -e uploadFlowResponse.txt ] && rm uploadFlowResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
