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
      # if this script is editing the ID of your recipe file, uncomment the line above and comment out the line below
      # sed -i '' "s/\"id\"[[:space:]]*:[[:space:]]*\"$ID_VALUE\"/\"id\": \"$NEW_ID\"/" "${FLOW}/metadata.json"
      # if you're getting `sed: 1: "...": invalid command code f` use the line above
      echo "Updated ID from '$ID_VALUE' to '$NEW_ID' in metadata.json"
    fi
  fi
fi

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