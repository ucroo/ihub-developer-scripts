#!/bin/sh
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
	http_response=$(curl $CURL_ARGS -s -o uploadSharedConfigFragmentResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" -H "referenceId: $FRAGMENT_NAME" -H "secure: $SECURE" "$HOST/repository/sharedConfig" --data-binary "@src/main/sharedConfig/$FRAGMENT_FILE")
fi

if [ $http_response != "200" ];
then
  if [ $http_response == "302" ];
  then
    echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
  else
    echo "Got unexpected HTTP response ${http_response}. This is likely an error."
  fi
else
  cat uploadSharedConfigFragmentResponse.txt
fi

[ -e uploadSharedConfigFragmentResponse.txt ] && rm uploadSharedConfigFragmentResponse.txt
