#!/bin/bash

# Signal failure the same way this script already did: `return` when sourced
# (repushAllConfig.sh sources several of these), `exit` when executed. Used
# only as the final statement, so control flow is unchanged either way.
[ "${BASH_SOURCE[0]}" = "$0" ] && _EXIT=exit || _EXIT=return
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

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadBundleResponse.txt -w "%{http_code}" -X DELETE -H "flow-token: $FLOW_TOKEN" "$HOST/ihub-viewer/repository/bundles?id=$BUNDLE")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadBundleResponse.txt"; then
  _status=1
else
	cat uploadBundleResponse.txt
	[ -e uploadBundleResponse.txt ] && rm uploadBundleResponse.txt
fi

[ "$_status" -ne 0 ] && $_EXIT 1
