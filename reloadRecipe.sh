#!/bin/sh
echo "Run this script from the same directory as your recipe metadata.json"
echo "Provide an environment shortname which is at least Flow V5.11."
case $# in
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
RECIPE_FAMILY=$(basename "`pwd`")
RECIPE=$(jq -r ".id" metadata.json)
echo "Refreshing ${RECIPE_FAMILY} - ${RECIPE}"
pushd ..
 uploadRecipe.sh "$RECIPE_FAMILY" "$ENV"
popd
source setEnvForUpload.sh "$ENV"
NOW=$(date +%s000)
DAY=$(expr 1000 \* 60 \* 60 \* 24)
YESTERDAY=$(expr $NOW - $DAY)
RECENT_RECIPE_EXECUTIONS=$(curl $CURL_ARGS -s -H "flow-token: $FLOW_TOKEN" "$HOST/repository/auditLogs?type=recipeExecution&start=$YESTERDAY&end=$NOW" )
INDEX=0
LENGTH=$(jq -r ". | length" <<< "$RECENT_RECIPE_EXECUTIONS")
for i in $(jq -r ".[] | .audited.id" <<< "$RECENT_RECIPE_EXECUTIONS"); do
 INDEX=$(expr $INDEX + 1)
 if [ "$i" = "$RECIPE" ]; then
    echo "Recent execution of " $i "found at index" $INDEX
    break
 fi
done

if [ $INDEX -ge $LENGTH ]; then
  echo "No recipe executions found on this server for" $RECIPE "in last 24 hours. Rerun through Recipe History."
else
  echo "Rerunning previous answers.  If they're incomplete, this will error and you need to go answer them in the interface and rerun this."
  PREVIOUS_ANSWERS=$(jq -r ".[$INDEX] | .audited.input" <<< "$RECENT_RECIPE_EXECUTIONS")
  curl $CURL_ARGS -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute?forceInstallAll=true" --data-binary "$PREVIOUS_ANSWERS"
fi