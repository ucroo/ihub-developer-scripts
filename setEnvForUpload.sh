#!/bin/bash

ENVIRONMENT=$1

CREDS_DIR=~/creds

API_HOST="https://api.$ENVIRONMENT.ucroo.org"
HOST="https://flow.$ENVIRONMENT.ucroo.org"
CURL_ARGS="$CURL_ARGS"

USER_LOC=$CREDS_DIR/$ENVIRONMENT.username
PASSWORD_LOC=$CREDS_DIR/$ENVIRONMENT.password
CURL_LOC=$CREDS_DIR/$ENVIRONMENT.curl
FLOW_LOC=$CREDS_DIR/$ENVIRONMENT.flow
API_LOC=$CREDS_DIR/$ENVIRONMENT.api

case $# in
    0)
        ENVIRONMENT="local"
        ;;
    *)
        ENVIRONMENT="$1"
        ;;
esac

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

COOKIE_NAME="COOKIE_$ENVIRONMENT"
COOKIE=${!COOKIE_NAME}
if [ -z $COOKIE ]
then
    echo "trying to get new cookie"
    USERNAME=$(cat $USER_LOC)
    PASSWORD=$(cat $PASSWORD_LOC)
    if [ -z $USERNAME ]
    then
        echo "please store the username in $USER_LOC"
    else
        if [ -z $PASSWORD ]
        then
            echo "please store the password in $PASSWORD_LOC"
        else
            COOKIE=$(curl -X POST --data-urlencode "username=$USERNAME" --data-urlencode "password=$PASSWORD" -H "Content-Type: application/x-www-form-urlencoded" $CURL_ARGS "$HOST/login/credentials/jsessionId/")
            COOKIE_TEST=$(curl --write-out %{http_code} --silent --output /dev/null -X GET -H "Cookie: JSESSIONID=$COOKIE" $CURL_ARGS "$HOST/login/currentlyLoggedIn")
            if [ $COOKIE_TEST -ne 200 ]
            then
                unset COOKIE
                echo "failed to get cookie with supplied username and password"
            else
                export COOKIE_$ENVIRONMENT=$COOKIE
            fi
        fi
    fi
else
    COOKIE_TEST=$(curl --write-out %{http_code} --silent --output /dev/null -X GET -H "Cookie: JSESSIONID=$COOKIE" $CURL_ARGS "$HOST/login/currentlyLoggedIn")
    if [ $COOKIE_TEST -ne 200 ]
    then
        echo "unsetting previous unhealthy cookie ($COOKIE_TEST)."
        unset COOKIE_$ENVIRONMENT
        echo "trying to get new cookie"
        USERNAME="$(cat $USER_LOC)"
        PASSWORD="$(cat $PASSWORD_LOC)"
        if [ -z $USERNAME ]
        then
            echo "please store the username in $USER_LOC"
        else
            if [ -z $PASSWORD ]
            then
                echo "please store the password in $PASSWORD_LOC"
            else
                COOKIE=$(curl -X POST --data-urlencode "username=$USERNAME" --data-urlencode "password=$PASSWORD" -H "Content-Type: application/x-www-form-urlencoded" $CURL_ARGS "$HOST/login/credentials/jsessionId/")
                if [ $COOKIE_TEST -ne 200 ]
                then
                    echo "failed to get cookie with supplied username and password"
                else
                    export COOKIE_$ENVIRONMENT=$COOKIE
                fi
            fi
        fi
    else
        echo "previous healthy cookie found."
    fi
fi;
