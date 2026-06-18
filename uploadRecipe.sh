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

# Build a throwaway, uploadable copy of the recipe. Every transform below runs
# against this staged copy, so the uploaded artifact can differ from disk
# without ever modifying your local working tree.
STAGING=$(mktemp -d)
mkdir -p "${STAGING}/$(dirname "$FLOW")"
cp -R "$FLOW" "${STAGING}/${FLOW}"
STAGED_FLOW="${STAGING}/${FLOW}"

# Check if metadata.json exists in the directory
if [ -f "${STAGED_FLOW}/metadata.json" ]; then
  # Extract the id value from metadata.json
  ID_VALUE=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "${STAGED_FLOW}/metadata.json" | cut -d'"' -f4)
  
  # Check if the ID ends with a semantic version pattern (digits separated by underscores)
  if ! echo "$ID_VALUE" | grep -q '_[0-9]\+_[0-9]\+_[0-9]\+$'; then
    # ID doesn't end with version, so look for the version key
    VERSION_VALUE=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "${STAGED_FLOW}/metadata.json" | cut -d'"' -f4)
    
    if [ -n "$VERSION_VALUE" ]; then
      # Replace dots with underscores in the version
      VERSION_FORMATTED=$(echo "$VERSION_VALUE" | tr '.' '_')
      
      # Create the new ID by appending the formatted version
      NEW_ID="${ID_VALUE}_${VERSION_FORMATTED}"
      
      # Update the staged metadata.json with the new ID. Use a temp file rather
      # than `sed -i`, whose syntax differs between GNU and BSD/macOS sed.
      ID_TMP=$(mktemp)
      sed "s/\"id\"[[:space:]]*:[[:space:]]*\"$ID_VALUE\"/\"id\": \"$NEW_ID\"/" "${STAGED_FLOW}/metadata.json" > "$ID_TMP" && mv "$ID_TMP" "${STAGED_FLOW}/metadata.json"
      
      echo "Updated ID from '$ID_VALUE' to '$NEW_ID' in the uploaded metadata.json"
    fi
  fi
fi

# update or insert a top-level string-valued key in a JSON file
upsert_json() {
  KEY="$1"
  VALUE="$2"
  FILE="$3"

  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg k "$KEY" --arg v "$VALUE" '.[$k] = $v' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
file, key, val = sys.argv[1], sys.argv[2], sys.argv[3]

with open(file, "r+") as f:
  data = json.load(f)
  data[key] = val
  f.seek(0)
  f.truncate()
  json.dump(data, f, indent=2)
' "$FILE" "$KEY" "$VALUE"
    return 0
  fi

  # No JSON tooling available: portable awk upsert. Updates the key in place
  # if present, otherwise inserts it right after the first opening brace.
  tmp=$(mktemp)
  awk -v k="$KEY" -v v="$VALUE" '
    found == 0 && index($0, "\"" k "\"") {
      sub("\"" k "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"", "\"" k "\": \"" v "\"")
      found = 1
    }
    { lines[NR] = $0 }
    brace == 0 && index($0, "{") { brace = NR }
    END {
      for (i = 1; i <= NR; i++) {
        print lines[i]
        if (found == 0 && i == brace) print "  \"" k "\": \"" v "\","
      }
    }
  ' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
}

# When uploading to a recipe development server, widen the version
# compatibility range so the recipe is always selectable there. Edits the
# staged copy only.
case "$ENVIRONMENT" in
  amanda|testing-manual)
    if [ -f "${STAGED_FLOW}/metadata.json" ]; then
      upsert_json "minVersion" "1.0.0" "${STAGED_FLOW}/metadata.json"
      upsert_json "maxVersion" "100.0.0" "${STAGED_FLOW}/metadata.json"
      echo "Set minVersion to 1.0.0 and maxVersion to 100.0.0 in the uploaded metadata.json because you are uploading to a recipe development server (${ENVIRONMENT}). Your local copy is left unchanged."
    fi
    ;;
esac

source setEnvForUpload.sh $ENVIRONMENT
[ -e "${FLOW}.zip" ] && rm ${FLOW}.zip
# Zip the staged copy, preserving the same archive layout as `zip -r ${FLOW}.zip $FLOW`.
( cd "$STAGING" && zip -r "${STAGING}/upload.zip" "$FLOW" )
mv "${STAGING}/upload.zip" "${FLOW}.zip"
if [ -z $FLOW_TOKEN ] ;
then
	rm -rf "$STAGING"
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${FLOW}.zip")
fi
if [ "$http_response" != "200" ];
then
  if [ "$http_response" = "302" ];
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
rm -rf "$STAGING"
