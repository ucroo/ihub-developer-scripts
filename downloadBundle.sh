#!/bin/bash

BUNDLE="$1"
ENVIRONMENT="$2"

case $# in
  2)
    ENVIRONMENT="$2"
    ;;
  1)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the bundle directory to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

rm "${BUNDLE}.zip"

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o "${BUNDLE}.zip" -w "%{http_code}" -X GET -H "flow-token: $FLOW_TOKEN" "$HOST/ihub-viewer/repository/bundles?format=flow-zip&id=$BUNDLE")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "${BUNDLE}.zip"; then
  _status=1
else
	unzip -o "${BUNDLE}.zip" > /dev/null
	[ -e "${BUNDLE}.zip" ] && rm "${BUNDLE}.zip"
fi

[ "$_status" -ne 0 ] && $_EXIT 1
