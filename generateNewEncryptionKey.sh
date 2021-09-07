#!/bin/bash
ENVIRONMENT="$1"

case $# in
  1)
    ENVIRONMENT="$1"
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
	curl $CURL_ARGS -X GET -H "flow-token: $FLOW_TOKEN" "$HOST/auth/s2s/encryption/generateNewKey" 
fi
