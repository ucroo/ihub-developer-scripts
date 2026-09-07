#!/bin/sh

# usage: uploadRecipe.sh <recipeDirectory> [environment] [--widen]
#
# --widen forces the uploaded copy to minVersion 1.0.0 / maxVersion 100.0.0,
# overwriting whatever range the recipe declares, so it is always selectable on
# a recipe development server. Without it, a declared range is uploaded as-is
# and only missing bounds are filled in.
FLOW=""
ENVIRONMENT=""
WIDEN_VERSIONS=false

for ARG in "$@"; do
  case "$ARG" in
    --widen)
      WIDEN_VERSIONS=true
      ;;
    -*)
      echo "unknown option: $ARG"
      echo "usage: uploadRecipe.sh <recipeDirectory> [environment] [--widen]"
      return 1
      ;;
    *)
      if [ -z "$FLOW" ]; then
        FLOW="$ARG"
      elif [ -z "$ENVIRONMENT" ]; then
        ENVIRONMENT="$ARG"
      else
        echo "too many arguments supplied: $ARG"
        echo "usage: uploadRecipe.sh <recipeDirectory> [environment] [--widen]"
        return 1
      fi
      ;;
  esac
done

if [ -z "$FLOW" ]; then
  echo "not enough arguments supplied.  You must supply the recipeDirectory to this command."
  return 1
fi

[ -z "$ENVIRONMENT" ] && ENVIRONMENT="local"

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
  # if present, otherwise inserts it right after the first opening brace. The
  # value pattern matches a quoted string or a bare token, so a key carrying
  # null is overwritten rather than left alone. found is driven by sub()'s own
  # result - keying it off the name alone would skip a value it cannot match
  # and then wrongly suppress the insert.
  tmp=$(mktemp)
  awk -v k="$KEY" -v v="$VALUE" '
    found == 0 {
      if (sub("\"" k "\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[^,}[:space:]]+)", "\"" k "\": \"" v "\"")) found = 1
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

# Succeed only if a top-level key is present with a non-empty value. A key that
# is absent, null or empty counts as missing, so it gets a default below.
json_has_value() {
  KEY="$1"
  FILE="$2"

  if command -v jq >/dev/null 2>&1; then
    jq -e --arg k "$KEY" \
      'has($k) and (.[$k] != null) and ((.[$k] | tostring) != "")' \
      "$FILE" >/dev/null 2>&1
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys

try:
  with open(sys.argv[1]) as f:
    data = json.load(f)
except Exception:
  sys.exit(1)

value = data.get(sys.argv[2])
sys.exit(0 if value is not None and str(value).strip() != "" else 1)
' "$FILE" "$KEY"
    return $?
  fi

  # No JSON tooling available: match the key against a non-empty string value.
  grep -q "\"$KEY\"[[:space:]]*:[[:space:]]*\"[^\"]\+\"" "$FILE"
}

# The flowServer rejects a recipe that declares no version compatibility range,
# so make sure the uploaded copy always carries one. Only missing fields are
# filled in - a range the recipe already declares is uploaded untouched unless
# --widen was given. Edits the staged copy only.
if [ -f "${STAGED_FLOW}/metadata.json" ]; then
  METADATA="${STAGED_FLOW}/metadata.json"

  if [ "$WIDEN_VERSIONS" = true ]; then
    upsert_json "minVersion" "1.0.0" "$METADATA"
    upsert_json "maxVersion" "100.0.0" "$METADATA"
    echo "Widened the uploaded metadata.json to minVersion 1.0.0 and maxVersion 100.0.0 because --widen was given. Your local copy is left unchanged."
  else
    PATCHED_VERSIONS=""

    if ! json_has_value "minVersion" "$METADATA"; then
      upsert_json "minVersion" "1.0.0" "$METADATA"
      PATCHED_VERSIONS="minVersion to 1.0.0"
    fi

    if ! json_has_value "maxVersion" "$METADATA"; then
      upsert_json "maxVersion" "100.0.0" "$METADATA"
      if [ -n "$PATCHED_VERSIONS" ]; then
        PATCHED_VERSIONS="${PATCHED_VERSIONS} and maxVersion to 100.0.0"
      else
        PATCHED_VERSIONS="maxVersion to 100.0.0"
      fi
    fi

    if [ -n "$PATCHED_VERSIONS" ]; then
      echo "Set ${PATCHED_VERSIONS} in the uploaded metadata.json because the recipe does not declare it. Your local copy is left unchanged."
    fi
  fi
fi

source setEnvForUpload.sh $ENVIRONMENT
[ -e "${FLOW}.zip" ] && rm "${FLOW}.zip"
# Zip the staged copy, preserving the same archive layout as `zip -r ${FLOW}.zip $FLOW`.
( cd "$STAGING" && zip -r "${STAGING}/upload.zip" "$FLOW" )
mv "${STAGING}/upload.zip" "${FLOW}.zip"
if [ -z $FLOW_TOKEN ] ;
then
	rm -rf "$STAGING"
	return 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadRecipeResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${FLOW}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${FLOW}.zip")
	curlStatus=$?
fi
_status=0
if ! validateHttpResponse "$curlStatus" "$http_response" "$FLOW" "uploadRecipeResponse.txt"; then
  _status=1
else
  cat uploadRecipeResponse.txt
fi
[ -e uploadRecipeResponse.txt ] && rm uploadRecipeResponse.txt
rm "${FLOW}.zip"
rm -rf "$STAGING"

if [ "$_status" -ne 0 ]; then
    $_EXIT 1
fi
