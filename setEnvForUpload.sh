#!/bin/bash

ENVIRONMENT=$1

CREDS_DIR=~/creds

CURL_ARGS="$CURL_ARGS"

case $# in
    0)
        ENVIRONMENT="local"
        ;;
    *)
        ENVIRONMENT="$1"
        ;;
esac

API_HOST="https://api.$ENVIRONMENT.ucroo.org"
HOST="https://flow.$ENVIRONMENT.ucroo.org"
CURL_LOC=$CREDS_DIR/$ENVIRONMENT.curl
FLOW_LOC=$CREDS_DIR/$ENVIRONMENT.flow
API_LOC=$CREDS_DIR/$ENVIRONMENT.api
FLOW_TOKEN_LOC=$CREDS_DIR/$ENVIRONMENT.token

if [ -f $CURL_LOC ]
then
	echo "overriding curl"
	CURL_ARGS="$CURL_ARGS $(cat $CURL_LOC)"
fi

if [ -f $API_LOC ]
then
	echo "overriding api"
	API_HOST="$(cat $API_LOC)"
fi

if [ -f $FLOW_LOC ]
then
	echo "overriding flow"
	HOST="$(cat $FLOW_LOC)"
fi

if [ -f $FLOW_TOKEN_LOC ]
then
	export FLOW_TOKEN=$(cat $FLOW_TOKEN_LOC)
	echo "using token" 
else
	echo "no available flow token.  You must have a $CREDS_DIR/$ENVIRONMENT.token file populated with an active flow access token from the server."
	return 1
fi
