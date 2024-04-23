#!/bin/sh
echo "Run this script from the same directory as your recipe metadata.json"
echo "Provide an environment shortname which is at least Flow V5.11."
echo "The first parameter must either be the environment shortname or an integer greater than 0 (the number of days to regard as 'recent' when fetching recent recipeExecutions, defaults to 1 day if not supplied)"
# Takes in up to three parameters: 
#   - environment ENV, defaults to 'local'
#   - number of days to fetch recipeExecutions for RECENT, defaults to 1
#   - a username to use to filter recipeExecutions RECIPEUSER
# Use the following flags to include each parameter:
#  ENV: -e
#  RECENT: -d
#  RECIPEUSER: -u
ENV='local'
RECIPEUSER='none'

while getopts d:u:e: flag
do
  case "${flag}" in
    d) RECENT=${OPTARG};;
    u) RECIPEUSER=${OPTARG};;
    e) ENV=${OPTARG};;
  esac
done

if [ -z "$RECENT" ]; then RECENT=1; fi
if ! [[ $RECENT =~ ^[0-9]+$ && $RECENT -gt 0 ]]; then echo "Days parameter, if provided, must be an integer greater than 0"; exit; fi

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

if ! [ $RECIPEUSER = 'none' ]; then
  PREVIOUS_ANSWERS=$(jq -r '[.[] | select(.audited.id=="'$RECIPE'" and .userName=="'$RECIPEUSER'" )][0] | .audited.input' <<< "$RECENT_RECIPE_EXECUTIONS")
else
  PREVIOUS_ANSWERS=$(jq -r '[.[] | select(.audited.id=="'$RECIPE'")][0] | .audited.input' <<< "$RECENT_RECIPE_EXECUTIONS")
fi

if [ $PREVIOUS_ANSWERS = 'null' ]; then
  if ! [ $RECIPEUSER = 'none' ]; then
    echo "No recipe executions by user:" $RECIPEUSER "found on server:" $ENV "for" $RECIPE "in last" $HOURS "hours. Rerun through Recipe History."
  else
    echo "No recipe executions found on server:" $ENV "for" $RECIPE "in last" $HOURS "hours. Rerun through Recipe History."
  fi
else
  echo "Rerunning previous answers.  If they're incomplete, this will error and you need to go answer them in the interface and rerun this."
  curl $CURL_ARGS -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute?forceInstallAll=true" --data-binary "$PREVIOUS_ANSWERS"
fi
