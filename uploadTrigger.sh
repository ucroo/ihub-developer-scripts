#!/bin/sh

# Signal failure the same way this script already did: `return` when sourced
# (repushAllConfig.sh sources several of these), `exit` when executed. Used
# only as the final statement, so control flow is unchanged either way.
[ "${BASH_SOURCE[0]}" = "$0" ] && _EXIT=exit || _EXIT=return
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
	http_response=$(curl $CURL_ARGS -s -o uploadTriggerResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/flowTriggerers" --data-binary "@src/main/triggerers/$SOURCE_FILE.json")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadTriggerResponse.txt"; then
  _status=1
else
  cat uploadTriggerResponse.txt
fi

[ -e uploadTriggerResponse.txt ] && rm uploadTriggerResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
