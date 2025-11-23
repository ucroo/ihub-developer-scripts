#!/bin/bash
ENVIRONMENT="$2"

case $# in
  1)
    ENVIRONMENT="$2"
    ;;
  *)
    ENVIRONMENT="local"
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	curl $CURL_ARGS -X GET -H "flow-token: $FLOW_TOKEN" "$HOST/ihub-viewer/repository/sharedConfig?encrypted=true" 
fi


