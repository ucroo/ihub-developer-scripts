#!/bin/bash
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

rm ${BUNDLE}.zip

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o ${BUNDLE}.zip -w "%{http_code}" -X GET -H "flow-token: $FLOW_TOKEN" "$HOST/repository/bundles?format=flow-zip&id=$BUNDLE")
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
	unzip -o ${BUNDLE}.zip > /dev/null
	[ -e ${BUNDLE}.zip ] && rm ${BUNDLE}.zip
fi
