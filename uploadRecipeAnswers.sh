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
    echo "not enough arguments supplied.  You must supply the recipe name to this command, and the name of the json file to send, and have a creds/${ENVIRONMENT}.username and creds/${ENVIRONMENT}.password file populated."
    return 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

if [ -z $COOKIE ]
then
  echo "no valid cookie"
  return 1
fi
curl $CURL_ARGS -X POST -H "Cookie: JSESSIONID=$COOKIE" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute" --data-binary "@$ANSWER"
