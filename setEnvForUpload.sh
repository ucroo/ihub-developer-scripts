#!/bin/bash

ENVIRONMENT=$1

CREDS_DIR=~/creds

# How the sourcing script should signal failure. BASH_SOURCE[1] is that script;
# if it equals $0 it was executed (exit), otherwise it was sourced by something
# else (return), as repushAllConfig.sh does. Set here so callers don't each
# repeat it. Only ever used as a script's final statement, so control flow is
# unchanged either way.
[ "${BASH_SOURCE[1]}" = "$0" ] && _EXIT=exit || _EXIT=return

#------------------------------------------------------------------------------
# Percent-encode a value for use in a URL path segment or query value.
#
# Entity names may contain spaces (a resource collection's directory name is
# its collectionId), and curl rejects the whole URL with
# "URL rejected: Malformed input to a URL function" if one is interpolated raw.
# Uploads sidestep this by passing the name in a header; deletes, triggers and
# ?id= callers put it in the URL and need encoding.
#
# usage: "$HOST/ihub-viewer/repository/flows/$(urlEncode "$FLOW")"
#------------------------------------------------------------------------------
urlEncode() {
	printf '%s' "$1" | jq -sRr @uri
}

#------------------------------------------------------------------------------
# Validate the outcome of a curl call that captured -w "%{http_code}".
#
# Separates three failures that all previously printed
# "Got unexpected HTTP response ." — curl never ran, curl ran but returned
# nothing, and a real non-200. Dumps the response body, which is where the
# actual diagnosis lives.
#
# usage: http_response=$(curl ... ); curlStatus=$?
#        validateHttpResponse "$curlStatus" "$http_response" <context> [bodyFile]
# returns: 0 on HTTP 200, 1 otherwise
#------------------------------------------------------------------------------
validateHttpResponse() {
	local curlStatus="$1"
	local response="$2"
	local context="${3:-request}"
	local bodyFile="${4:-}"

	if [ "$curlStatus" -ne 0 ]; then
		echo "curl failed before any HTTP exchange for '$context' (see error above) — nothing was sent."
		return 1
	fi

	if [ "$response" = "200" ]; then
		return 0
	fi

	if [ -z "$response" ]; then
		echo "No HTTP response received for '$context'; the request never completed. Check that the payload file was created."
	elif [ "$response" = "302" ]; then
		echo "Got unexpected HTTP response $response for '$context'. This is likely due to your token being incorrect."
	elif [ "$response" = "401" ] || [ "$response" = "403" ]; then
		echo "Got unexpected HTTP response $response for '$context'. The $ENVIRONMENT token is missing, expired, or lacks permission."
	else
		echo "Got unexpected HTTP response $response for '$context'. This is likely an error."
	fi

	if [ -n "$bodyFile" ] && [ -s "$bodyFile" ]; then
		echo "--- response body ---"
		cat "$bodyFile"
		echo "--- end response body ---"
	fi

	return 1
}

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

# Callers build URLs as "$HOST/path", so a trailing slash in the override file
# produces "//path". Jetty rejects that with 400 "Ambiguous URI empty segment"
# before authentication runs, which reads like a bad token but isn't.
API_HOST="${API_HOST%/}"
HOST="${HOST%/}"

if [ -f $FLOW_TOKEN_LOC ]
then
	export FLOW_TOKEN=$(cat $FLOW_TOKEN_LOC)
	echo "using token" 
else
	echo "no available flow token.  You must have a $CREDS_DIR/$ENVIRONMENT.token file populated with an active flow access token from the server."
	return 1
fi
