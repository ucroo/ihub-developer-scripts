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
    echo "not enough arguments supplied.  You must supply the recipeDirectory to this command."
    return 1
    ;;
esac    

# Check if metadata.json exists in the directory
if [ -f "${FLOW}/metadata.json" ]; then
  # Extract the id value from metadata.json
  ID_VALUE=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "${FLOW}/metadata.json" | cut -d'"' -f4)
  
  # Check if the ID ends with a semantic version pattern (digits separated by underscores)
  if ! echo "$ID_VALUE" | grep -q '_[0-9]\+_[0-9]\+_[0-9]\+$'; then
    # ID doesn't end with version, so look for the version key
    VERSION_VALUE=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${FLOW}/metadata.json" | cut -d'"' -f4)
    
    if [ -n "$VERSION_VALUE" ]; then
      # Replace dots with underscores in the version
      VERSION_FORMATTED=$(echo "$VERSION_VALUE" | tr '.' '_')
      
      # Create the new ID by appending the formatted version
      NEW_ID="${ID_VALUE}_${VERSION_FORMATTED}"
      
      # Update the metadata.json file with the new ID
      sed -i "s/\"id\"[[:space:]]*:[[:space:]]*\"$ID_VALUE\"/\"id\": \"$NEW_ID\"/" "${FLOW}/metadata.json"
      
      echo "Updated ID from '$ID_VALUE' to '$NEW_ID' in metadata.json"
    fi
  fi
fi

# Set (or insert) a top-level string-valued key in a JSON file (GNU sed)
set_metadata_key() {
  KEY="$1"
  VALUE="$2"
  FILE="$3"
  if grep -q "\"$KEY\"[[:space:]]*:" "$FILE"; then
    sed -i "s/\"$KEY\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$KEY\": \"$VALUE\"/" "$FILE"
  else
    # Key not present: insert it right after the opening brace
    sed -i "0,/{/s//{\n  \"$KEY\": \"$VALUE\",/" "$FILE"
  fi
}

# When uploading to a recipe development server, widen the version
# compatibility range so the recipe is always selectable there.
case "$ENVIRONMENT" in
  amanda|testing-manual)
    if [ -f "${FLOW}/metadata.json" ]; then
      set_metadata_key "minVersion" "1.0.0" "${FLOW}/metadata.json"
      set_metadata_key "maxVersion" "100.0.0" "${FLOW}/metadata.json"
      echo "Set minVersion to 1.0.0 and maxVersion to 100.0.0 in metadata.json because you are uploading to a recipe development server (${ENVIRONMENT})."
    fi
    ;;
esac

source setEnvForUpload.sh $ENVIRONMENT
[ -e "${FLOW}.zip" ] && rm ${FLOW}.zip
zip -r ${FLOW}.zip $FLOW
if [ -z $FLOW_TOKEN ] ;
then
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${FLOW}.zip")
fi
if [ $http_response != "200" ];
then
  if [ $http_response == "302" ];
  then
    echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
  else
    echo "Got unexpected HTTP response ${http_response}. This is likely an error."
		cat uploadRecipeResponse.txt
  fi
else
  cat uploadRecipeResponse.txt
fi
[ -e uploadRecipeResponse.txt ] && rm uploadRecipeResponse.txt
rm ${FLOW}.zip
