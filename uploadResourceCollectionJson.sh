#!/bin/bash

# Signal failure the same way this script already did: `return` when sourced
# (repushAllConfig.sh sources several of these), `exit` when executed. Used
# only as the final statement, so control flow is unchanged either way.
[ "${BASH_SOURCE[0]}" = "$0" ] && _EXIT=exit || _EXIT=return
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
    echo "not enough arguments supplied.  You must supply the resourceCollection directory to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadResourceCollectionJsonResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/resourceCollections" --data-binary "@${FLOW}.json")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadResourceCollectionJsonResponse.txt"; then
  _status=1
else
  cat uploadResourceCollectionJsonResponse.txt
fi

[ -e uploadResourceCollectionJsonResponse.txt ] && rm uploadResourceCollectionJsonResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
