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
    echo "not enough arguments supplied.  You must supply the resourceCollection directory to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

# Collection directory names can contain spaces (the name is the Flow
# collectionId, so it cannot be renamed), which word-splits when unquoted.
rm "${FLOW}.zip"
zip -r "${FLOW}.zip" "$FLOW"

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadResourceCollectionResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/ihub-viewer/repository/resourceCollections" --data-binary "@${FLOW}.zip")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadResourceCollectionResponse.txt"; then
  _status=1
else
  cat uploadResourceCollectionResponse.txt
fi

[ -e uploadResourceCollectionResponse.txt ] && rm uploadResourceCollectionResponse.txt
rm "${FLOW}.zip"

[ "$_status" -ne 0 ] && $_EXIT 1
