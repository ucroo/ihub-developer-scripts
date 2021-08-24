#!/bin/sh
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
    echo "not enough arguments supplied.  You must supply the recipeDirectory to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

rm ${FLOW}.zip
zip -r ${FLOW}.zip $FLOW

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	curl $CURL_ARGS -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/repository/recipes" --data-binary "@${FLOW}.zip"
fi
rm ${FLOW}.zip
