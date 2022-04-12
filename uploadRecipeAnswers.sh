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
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeAnswersResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute" --data-binary "@$ANSWER")
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
  cat uploadRecipeAnswersResponse.txt
fi

rm uploadRecipeAnswersResponse.txt
