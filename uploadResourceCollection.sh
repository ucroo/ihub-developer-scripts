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
    echo "not enough arguments supplied.  You must supply the resourceCollection directory to this command."
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
	http_response=$(curl $CURL_ARGS -s -o uploadResourceCollectionResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/repository/resourceCollections" --data-binary "@${FLOW}.zip")
fi

if [ $http_response != "200" ];
then
  if [ $http_response == "302" ];
  then
    echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
  else
    echo "Got unexpected HTTP response ${http_response}. This is likely an error."
  fi

  return 1
else
  cat uploadResourceCollectionResponse.txt
fi

[ -e uploadResourceCollectionResponse.txt ] && rm uploadResourceCollectionResponse.txt
rm ${FLOW}.zip
