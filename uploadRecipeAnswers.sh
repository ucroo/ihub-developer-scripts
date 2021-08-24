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
	curl $CURL_ARGS -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute" --data-binary "@$ANSWER"
fi
