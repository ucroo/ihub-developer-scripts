#!/bin/bash

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
	http_response=$(curl $CURL_ARGS -s -o uploadConfigPanelResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/configPanels" --data-binary "@src/main/configPanels/$SOURCE_FILE.json")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadConfigPanelResponse.txt"; then
  _status=1
else
  cat uploadConfigPanelResponse.txt
fi

[ -e uploadConfigPanelResponse.txt ] && rm uploadConfigPanelResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
