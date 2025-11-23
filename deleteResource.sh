#!/bin/bash
RESID="$1"
RESCOL="$2"
ENVIRONMENT="$3"

case $# in
  3)
    ENVIRONMENT="$3"
    ;;
  2)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the resourceId and resourceCollectionId to this command."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	curl $CURL_ARGS -X DELETE -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/ihub-viewer/repository/resourceCollections/$RESCOL/resources/$RESID" 
fi
