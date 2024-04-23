#!/bin/sh
echo "Run this script from the same directory as your recipe metadata.json"
echo "Provide an environment shortname which is at least Flow V5.11."
RECENT=0
case $# in
  2)
    ENV="$1"
    RECENT="$2"
    ;;
  1)
    ENV="$1"
    ;;
  0)
    ENV="local"
    ;;
  *)
    return 1
    ;;
esac

if ! [[ $RECENT =~ ^[0-9]+$ ]]; then
 echo "Second parameter, if provided, must be an integer greater than 0"
 exit
fi

if [[ $ENV =~ ^[0-9]+$ ]]; then
  echo "Integer input as first parameter, defaulting to local environment"
  RECENT=$ENV
  ENV="local"
fi

if ! [[ $RECENT -gt 0 ]]; then
  echo "No valid input for RECENT, defaulting to 1 day"
  RECENT=1
fi

RECIPE_FAMILY=$(basename "`pwd`")
RECIPE=$(jq -r ".id" metadata.json)
echo "Refreshing ${RECIPE_FAMILY} - ${RECIPE}"
pushd ..
 uploadRecipe.sh "$RECIPE_FAMILY" "$ENV"
popd
source setEnvForUpload.sh "$ENV"
NOW=$(date +%s000)
DAY=$(expr 1000 \* 60 \* 60 \* 24 \* $RECENT)
YESTERDAY=$(expr $NOW - $DAY)
RECENT_RECIPE_EXECUTIONS=$(curl $CURL_ARGS -s -H "flow-token: $FLOW_TOKEN" "$HOST/repository/auditLogs?type=recipeExecution&start=$YESTERDAY&end=$NOW" )
HOURS=$(expr 24 \* $RECENT)
PREVIOUS_ANSWERS=$(jq -r '[.[] | select(.audited.id=="'$RECIPE'")][0] | .audited.input' <<< "$RECENT_RECIPE_EXECUTIONS")
if [ $PREVIOUS_ANSWERS = 'null' ]; then
  echo "No recipe executions found on this server for" $RECIPE "in last" $HOURS "hours. Rerun through Recipe History."
else
  echo "Rerunning previous answers.  If they're incomplete, this will error and you need to go answer them in the interface and rerun this."
  curl $CURL_ARGS -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute?forceInstallAll=true" --data-binary "$PREVIOUS_ANSWERS"
fi
