#!/bin/sh

# Signal failure the same way this script already did: `return` when sourced
# (repushAllConfig.sh sources several of these), `exit` when executed. Used
# only as the final statement, so control flow is unchanged either way.
[ "${BASH_SOURCE[0]}" = "$0" ] && _EXIT=exit || _EXIT=return
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
	http_response=$(curl $CURL_ARGS -s -o uploadSharedConfigFragmentResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" -H "referenceId: $FRAGMENT_NAME" -H "secure: $SECURE" "$HOST/ihub-viewer/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FRAGMENT_FILE")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadSharedConfigFragmentResponse.txt"; then
  _status=1
else
  cat uploadSharedConfigFragmentResponse.txt
fi

[ -e uploadSharedConfigFragmentResponse.txt ] && rm uploadSharedConfigFragmentResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
