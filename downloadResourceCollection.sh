#!/bin/bash
RESCOL="$1"
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

rm ${RESCOL}.zip

if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o ${RESCOL}.zip -w "%{http_code}" -X GET -H "flow-token: $FLOW_TOKEN" "$HOST/repository/resourceCollections?format=flow-zip&id=$RESCOL")
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
	unzip -o ${RESCOL}.zip > /dev/null
	[ -e ${RESCOL}.zip ] && rm ${RESCOL}.zip
fi
