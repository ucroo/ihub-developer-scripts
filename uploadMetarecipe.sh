#!/bin/bash

#!/bin/sh
# usage: uploadMetarecipe.sh <recipeDirectory> [environment] [--widen]
#
# --widen forces every uploaded copy - parent and children - to minVersion
# 1.0.0 / maxVersion 100.0.0, overwriting whatever range each recipe declares,
# so they are always selectable on a recipe development server. Without it, a
# declared range is uploaded as-is and only missing bounds are filled in.
METARECIPE=""
ENVIRONMENT=""
WIDEN_VERSIONS=false

for ARG in "$@"; do
  case "$ARG" in
    --widen)
      WIDEN_VERSIONS=true
      ;;
    -*)
      echo "unknown option: $ARG"
      echo "usage: uploadMetarecipe.sh <recipeDirectory> [environment] [--widen]"
      return 1
      ;;
    *)
      if [ -z "$METARECIPE" ]; then
        METARECIPE="$ARG"
      elif [ -z "$ENVIRONMENT" ]; then
        ENVIRONMENT="$ARG"
      else
        echo "too many arguments supplied: $ARG"
        echo "usage: uploadMetarecipe.sh <recipeDirectory> [environment] [--widen]"
        return 1
      fi
      ;;
  esac
done

if [ -z "$METARECIPE" ]; then
  echo "not enough arguments supplied.  You must supply the recipeDirectory to this command."
  return 1
fi

[ -z "$ENVIRONMENT" ] && ENVIRONMENT="local"

# update or insert a top-level string-valued key in a JSON file. jq is already a
# hard dependency of this script (it derives CHILD_RECIPES below), so use it
# directly rather than carrying uploadRecipe.sh's python3/awk fallbacks.
upsert_json() {
  KEY="$1"
  VALUE="$2"
  FILE="$3"
  tmp=$(mktemp)
  if jq --arg k "$KEY" --arg v "$VALUE" '.[$k] = $v' "$FILE" > "$tmp"; then
    mv "$tmp" "$FILE"
  else
    rm -f "$tmp"
    return 1
  fi
}

# Succeed only if a top-level key is present with a non-empty value. A key that
# is absent, null or empty counts as missing, so it gets a default below.
# Invalid JSON also counts as missing, and the upsert that follows then fails
# and reports the warning.
json_has_value() {
  jq -e --arg k "$1" \
    'has($k) and (.[$k] != null) and ((.[$k] | tostring) != "")' \
    "$2" >/dev/null 2>&1
}

# The flowServer rejects a recipe that declares no version compatibility range,
# so make sure every uploaded copy carries one. Only missing fields are filled
# in, unless --widen was given. Edits the staged copy only.
#   patch_versions <staged metadata.json> <label for messages>
patch_versions() {
  FILE="$1"
  LABEL="$2"

  if [ "$WIDEN_VERSIONS" = true ]; then
    if upsert_json "minVersion" "1.0.0" "$FILE" \
      && upsert_json "maxVersion" "100.0.0" "$FILE"; then
      echo "Widened the uploaded ${LABEL} to minVersion 1.0.0 and maxVersion 100.0.0 because --widen was given. Your local copy is left unchanged."
    else
      echo "Warning: could not set minVersion/maxVersion in ${LABEL} (invalid JSON?). Uploading it unmodified."
    fi
    return
  fi

  PATCHED_VERSIONS=""
  PATCH_FAILED=false

  if ! json_has_value "minVersion" "$FILE"; then
    if upsert_json "minVersion" "1.0.0" "$FILE"; then
      PATCHED_VERSIONS="minVersion to 1.0.0"
    else
      PATCH_FAILED=true
    fi
  fi

  if ! json_has_value "maxVersion" "$FILE"; then
    if upsert_json "maxVersion" "100.0.0" "$FILE"; then
      if [ -n "$PATCHED_VERSIONS" ]; then
        PATCHED_VERSIONS="${PATCHED_VERSIONS} and maxVersion to 100.0.0"
      else
        PATCHED_VERSIONS="maxVersion to 100.0.0"
      fi
    else
      PATCH_FAILED=true
    fi
  fi

  if [ "$PATCH_FAILED" = true ]; then
    echo "Warning: could not set minVersion/maxVersion in ${LABEL} (invalid JSON?). Uploading it unmodified."
  elif [ -n "$PATCHED_VERSIONS" ]; then
    echo "Set ${PATCHED_VERSIONS} in the uploaded ${LABEL} because the recipe does not declare it. Your local copy is left unchanged."
  fi
}

CHILD_RECIPES=$(jq -r '.bindings | .. | select(type == "object" and has("recipeId") and .variableType == "recipeExecution") | .recipeId | sub("(_[0-9]+){3}$"; "")' $METARECIPE/metadata.json)

if [ -z "$CHILD_RECIPES" ];
then
  echo "Error encountered or this is not a metarecipe, please use uploadRecipe.sh"
else
   source setEnvForUpload.sh $ENVIRONMENT
  if [ -z $FLOW_TOKEN ] ;
  then
    return 1
  else
    RESPONSES=$'\nNone of the recipes required by this metarecipe were uploaded successfully:'
    bold=$(tput bold)
    normal=$(tput sgr0)
    ERRORS_FOUND=false
    FIRST_UPLOADED=true
    for i in $METARECIPE $CHILD_RECIPES; do
      echo $i
      #based on uploadRecipe.sh
      # Build a throwaway, uploadable copy of this recipe. Every transform below
      # runs against the staged copy, so the uploaded artifact can differ from
      # disk without ever modifying your local working tree.
      STAGING=$(mktemp -d)
      mkdir -p "${STAGING}/$(dirname "$i")"
      cp -R "$i" "${STAGING}/${i}"

      # Give every recipe a version compatibility range so the flowServer does
      # not reject it, regardless of which environment this is going to.
      if [ -f "${STAGING}/${i}/metadata.json" ]; then
        patch_versions "${STAGING}/${i}/metadata.json" "${i}/metadata.json"
      fi

      [ -e "${i}.zip" ] && rm "${i}.zip"
      # Zip the staged copy, preserving the same archive layout as `zip -r ${i}.zip $i`.
      ( cd "$STAGING" && zip -r "${STAGING}/upload.zip" "$i" )
      mv "${STAGING}/upload.zip" "${i}.zip"
      http_response=$(curl $CURL_ARGS -s -o ${i}.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${i}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${i}.zip")
      curlStatus=$?
      _status=0
      if ! validateHttpResponse "$curlStatus" "$http_response" "$METARECIPE" "${i}.txt"; then
        _status=1
        cat ${i}.txt
        rm ${i}.txt
        [ -e "${i}.zip" ] && rm "${i}.zip"
        rm -rf "$STAGING"
        ERRORS_FOUND=true
        break
      else
        if [ "$FIRST_UPLOADED" = true ]; then
          RESPONSES=$'\nThe following recipes required by this metarecipe were uploaded successfully:'
          FIRST_UPLOADED=false
        fi
        cat ${i}.txt
        printf "\n\n"
        RESPONSES+=$'\n'
        RESPONSES+=$(< ${i}.txt)
        [ -e ${i}.txt ] && rm ${i}.txt
        rm "${i}.zip"
        rm -rf "$STAGING"
      fi
    done
    if [ "$ERRORS_FOUND" = false ]; then
      printf "\n\n${bold}Uploading to %s complete. Included recipes:${normal}\n - Parent recipe: %s\n" $ENVIRONMENT $METARECIPE
      for i in $CHILD_RECIPES; do
      echo " - Child recipe: " $i
      done
      echo "$RESPONSES"
    fi
  fi
fi

if [ "$_status" -ne 0 ]; then
    $_EXIT 1
fi
