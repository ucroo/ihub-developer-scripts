#!/usr/bin/env bash

set -eo pipefail

# Print error message to stderr and exit
fatal() {
	>&2 echo "error: $*"
	exit 1
}

# Print usage information to stderr and exit
usage() {
	[ "$#" = "0" ] || >&2 echo "error: $*"
	>&2 cat <<-EOF
		usage: $(basename "$0") [-e ENV] [-d DAYS] [-u RECIPE_USER]

		  -e ENV           environment (e.g. avc, qa-rollins) defaults to 'local'
		  -d DAYS          number of days to fetch recipeExecutions for RECENT, defaults to 1
		  -u RECIPE_USER   a username to use to filter recipeExecutions RECIPEUSER

		To provide an environment, use -e followed by an environment shortname. The default environment is local.

		Note: Target environments must be at least Flow V5.11."
	EOF
	exit 1
}

ENV='local'
RECIPEUSER='none'

while getopts d:u:e: flag; do
	case "${flag}" in
	d)
		RECENT=${OPTARG}
		;;
	u)
		RECIPEUSER=${OPTARG}
		;;
	e)
		ENV=${OPTARG}
		;;
	*)
		usage
		;;
	esac
done

shift $((OPTIND - 1))

[ "$#" = "0" ] || usage "unrecognized arguments: $*"

RECENT="${RECENT:-1}"
(("$RECENT" > 0)) || fatal "-d argument (i.e. $RECENT) must be a number that is greater than 0."

RECIPE_FAMILY=$(basename "$(pwd)")

[ -r "./metadata.json" ] || fatal "No metadata.json found. Run this script from the same directory as your recipe metadata.json"

RECIPE=$(jq -r ".id" metadata.json)
echo "Reloading ${RECIPE_FAMILY} - ${RECIPE} on ${ENV}..."
source setEnvForUpload.sh "$ENV" || fatal "cannot setup environment variables."

pushd .. >/dev/null
uploadRecipe.sh "$RECIPE_FAMILY" "$ENV" || true
popd >/dev/null || exit 1
echo

NOW=$(date +%s000)
DAY=$((1000 * 60 * 60 * 24 * RECENT))
YESTERDAY=$((NOW - DAY))

RECENT_RECIPE_EXECUTIONS=$(
	# shellcheck disable=SC2086
	curl $CURL_ARGS -s \
		-H "flow-token: $FLOW_TOKEN" \
		"$HOST/ihub-viewer/repository/auditLogs?type=recipeExecution&start=$YESTERDAY&end=$NOW"
)

[ -n "$RECENT_RECIPE_EXECUTIONS" ] || fatal "No recent recipe executions found on this server. Please run the recipe manually."

if ! [ "$RECIPEUSER" = 'none' ]; then
	PREVIOUS_ANSWERS=$(jq -r '[
           .[] | 
					 select(.audited.id | startswith("'"$RECIPE_FAMILY"'") and .userName=="'"$RECIPEUSER"'" )][0] | 
           .audited.input' <<<"$RECENT_RECIPE_EXECUTIONS")
else
	PREVIOUS_ANSWERS=$(jq -r '[
           .[] | 
						 select(.audited.id | startswith("'"$RECIPE_FAMILY"'"))][0] | 
           .audited.input' <<<"$RECENT_RECIPE_EXECUTIONS")
fi

HOURS=$((24 * RECENT))

if [ "$PREVIOUS_ANSWERS" = 'null' ]; then
	if ! [ "$RECIPEUSER" = 'none' ]; then
		echo "No recipe executions by user: $RECIPEUSER found on server: $ENV for $RECIPE in last $HOURS hours. Rerun through Recipe History."
	else
		echo "No recipe executions found on server: $ENV for $RECIPE in last $HOURS hours. Rerun through Recipe History."
	fi
else
	echo "Rerunning recipe with previous answers.  If they're incomplete, this will fail and you need to go answer them in the interface and rerun this script."
	# shellcheck disable=SC2086
	curl $CURL_ARGS -H "flow-token: $FLOW_TOKEN" \
		-H "Content-Type: application/json" \
		"$HOST/ihub-viewer/repository/recipes/$RECIPE/execute?forceInstallAll=true" \
		--data-binary "$PREVIOUS_ANSWERS"
	echo
fi
