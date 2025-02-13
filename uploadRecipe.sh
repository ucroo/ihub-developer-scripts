#!/bin/sh
FLOW="$1"
ENVIRONMENT="$2"

case $# in
  2)
    ENVIRONMENT="$2"
    ;;
  1)
    ENVIRONMENT="local"
    ;;
  *)
    echo "Not enough arguments supplied. You must supply the recipe directory."
    exit 1
    ;;
esac    

source setEnvForUpload.sh "$ENVIRONMENT"

declare -A PROCESSED_RECIPES

zip_and_upload() {
  echo $PROCESSED_RECIPES
  local RECIPE="$1"

  # Prevent reprocessing
  # if [ "${PROCESSED_RECIPES[$RECIPE]}" ]; then
  #   return
  # fi
  # PROCESSED_RECIPES[$RECIPE]=1

  if [ ! -d "$RECIPE" ]; then
    echo "Recipe directory $RECIPE does not exist, skipping..."
    return
  fi

  echo "Zipping and uploading: $RECIPE"
  [ -e "${RECIPE}.zip" ] && rm "${RECIPE}.zip"
  zip -r "${RECIPE}.zip" "$RECIPE"

  if [ -z "$FLOW_TOKEN" ]; then
    echo "FLOW_TOKEN is not set. Exiting."
    exit 1
  fi

  http_response=$(curl $CURL_ARGS -s -o uploadRecipeResponse.txt -w "%{http_code}" -X POST \
    -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" \
    -H "format: zip" -H "name: ${RECIPE}" "$HOST/repository/recipes" \
    --data-binary "@${RECIPE}.zip")

  echo "${HOST}"

  if [ "$http_response" != "200" ]; then
    if [ "$http_response" = "302" ]; then
      echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
    else
      echo "Got unexpected HTTP response ${http_response}. This is likely an error."
    fi
  else
    cat uploadRecipeResponse.txt
  fi

  [ -e uploadRecipeResponse.txt ]

  METADATA_FILE="${RECIPE}/metadata.json"
  if [ -f "$METADATA_FILE" ]; then
    local child_recipes=$(jq -r '.bindings | to_entries[] | select(.value.variableType == "recipeExecution") | .value.recipeId' "$METADATA_FILE" | sort -u)
    
    for child_recipe in $child_recipes; do
      zip_and_upload "$child_recipe"
    done
  fi
}

zip_and_upload "$FLOW"
