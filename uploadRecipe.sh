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

      # Update the metadata.json file with the new ID.
      # `sed -i.bak` then remove the backup is portable across GNU sed (Linux)
      # and BSD sed (macOS); plain `sed -i` is GNU-only and fails silently on
      # macOS with "sed: -I or -i may not be used with stdin".
      sed -i.bak "s/\"id\"[[:space:]]*:[[:space:]]*\"$ID_VALUE\"/\"id\": \"$NEW_ID\"/" "${FLOW}/metadata.json"
      rm -f "${FLOW}/metadata.json.bak"

      echo "Updated ID from '$ID_VALUE' to '$NEW_ID' in metadata.json"
    fi
  fi
fi

source setEnvForUpload.sh $ENVIRONMENT

# Zip with the recipe directory at the archive root, regardless of whether
# $FLOW was passed in as "request_collegium_invite", "recipes/request_collegium_invite",
# or "/abs/path/.../request_collegium_invite". Flow's POST /repository/recipes
# silently rejects zips whose entries are nested under a parent path: it
# responds with HTTP 200 and body "[]", and the recipe is never registered.
FLOW_PARENT=$(cd "$(dirname "$FLOW")" && pwd)
FLOW_BASE=$(basename "$FLOW")
ZIP_PATH="/tmp/${FLOW_BASE}-upload.zip"
[ -e "$ZIP_PATH" ] && rm -f "$ZIP_PATH"
( cd "$FLOW_PARENT" && zip -r "$ZIP_PATH" "$FLOW_BASE" )

if [ -z $FLOW_TOKEN ] ;
then
	rm -f "$ZIP_PATH"
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW_BASE}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${ZIP_PATH}")
fi
rc=0
if [ $http_response != "200" ];
then
  if [ $http_response == "302" ];
  then
    echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
  else
    echo "Got unexpected HTTP response ${http_response}. This is likely an error."
		cat uploadRecipeResponse.txt
  fi
  rc=1
else
  # HTTP 200 alone is not enough. Flow returns 200 + "[]" when the zip is
  # structurally wrong (e.g. entries nested under a parent dir, or the recipe
  # otherwise fails server-side validation). A successful create/update returns
  # a JSON object with "mutation":"Create"/"Update" and "id":"<recipe>_X_Y_Z".
  body=$(cat uploadRecipeResponse.txt)
  cat uploadRecipeResponse.txt
  case "$body" in
    "[]"|"")
      echo ""
      echo "ERROR: upload returned HTTP 200 with empty body \"$body\". Recipe was NOT registered." >&2
      echo "Common cause: zip entries nested under a parent path. ${FLOW_BASE}/ must be at the archive root." >&2
      rc=1
      ;;
    *success*|*Create*|*Update*)
      :
      ;;
    *)
      echo ""
      echo "WARNING: upload returned HTTP 200 but the body does not contain a success marker." >&2
      rc=1
      ;;
  esac
fi
[ -e uploadRecipeResponse.txt ] && rm uploadRecipeResponse.txt
[ -e "$ZIP_PATH" ] && rm -f "$ZIP_PATH"
return $rc
