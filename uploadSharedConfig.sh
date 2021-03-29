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
    echo "not enough arguments supplied.  You must supply the flowName to this command, and have a creds/${ENVIRONMENT}.username and creds/${ENVIRONMENT}.password file populated."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $FLOW_TOKEN ] ;
then
	if [ -z $COOKIE ] ;
	then
		echo "no cookie found"
		return 1
	fi
	curl $CURL_ARGS -X POST -H "Cookie: JSESSIONID=$COOKIE" -H "Content-Type: application/json" "$HOST/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FLOW.json"
else
	curl $CURL_ARGS -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FLOW.json"
fi
