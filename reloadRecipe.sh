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
echo "Rerunning previous answers.  If they're incomplete, this will error and you need to go answer them in the interface and rerun this."
PREVIOUS_RUN=$(curl $CURL_ARGS -s -H "flow-token: $FLOW_TOKEN" "$HOST/repository/auditLogs?type=recipeExecution&limit=1" )
ID=$(jq -r ".[0] | .audited.id" <<< "$PREVIOUS_RUN")

if [ "$ID" = "$RECIPE" ]; then
  PREVIOUS_ANSWERS=$(jq -r ".[0] | .audited.input" <<< "$PREVIOUS_RUN")
  curl $CURL_ARGS -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/json" "$HOST/repository/recipes/$RECIPE/execute?forceInstallAll=true" --data-binary "$PREVIOUS_ANSWERS"
else
  echo "Last recipe execution: " $ID "Attempted recipe execution: " $RECIPE "rerun through Recipe History" 
fi