#!/bin/sh

RECIPE="$1"
ANSWER="$2"
ENVIRONMENT="$3"

case $# in
  3)
    ENVIRONMENT="$3"
    ;;
  2)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the recipe name to this command, and the name of the json file to send."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeAnswersResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/recipes/$RECIPE/execute?forceInstallAll=true" --data-binary "@$ANSWER")
	curlStatus=$?
fi

_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$1" "uploadRecipeAnswersResponse.txt"; then
  _status=1
else
  cat uploadRecipeAnswersResponse.txt
fi

[ -e uploadRecipeAnswersResponse.txt ] && rm uploadRecipeAnswersResponse.txt

[ "$_status" -ne 0 ] && $_EXIT 1
