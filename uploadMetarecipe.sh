#!/bin/bash
#!/bin/sh
METARECIPE="$1"
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

      # When uploading to a recipe development server, widen the version
      # compatibility range so every recipe (parent and children) is always
      # selectable there. Edits the staged copy only.
      case "$ENVIRONMENT" in
        amanda|testing-manual)
          if [ -f "${STAGING}/${i}/metadata.json" ]; then
            if upsert_json "minVersion" "1.0.0" "${STAGING}/${i}/metadata.json" \
              && upsert_json "maxVersion" "100.0.0" "${STAGING}/${i}/metadata.json"; then
              echo "Set minVersion to 1.0.0 and maxVersion to 100.0.0 in the uploaded ${i}/metadata.json because you are uploading to a recipe development server (${ENVIRONMENT}). Your local copy is left unchanged."
            else
              echo "Warning: could not set minVersion/maxVersion in ${i}/metadata.json (invalid JSON?). Uploading it unmodified."
            fi
          fi
          ;;
      esac

      [ -e "${i}.zip" ] && rm ${i}.zip
      # Zip the staged copy, preserving the same archive layout as `zip -r ${i}.zip $i`.
      ( cd "$STAGING" && zip -r "${STAGING}/upload.zip" "$i" )
      mv "${STAGING}/upload.zip" "${i}.zip"
      http_response=$(curl $CURL_ARGS -s -o ${i}.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" -H "format: zip" -H "name: ${i}" "$HOST/ihub-viewer/repository/recipes" --data-binary "@${i}.zip")
      if [ $http_response != "200" ];
      then
        echo "$RESPONSES"
        printf "\n${bold}Error encountered${normal} while uploading %s. Not continuing. Error encountered: " $i
        if [ $http_response == "302" ];
        then
          echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
        else
          echo "Got unexpected HTTP response ${http_response}. This is likely an error."
        fi
        cat ${i}.txt
        rm ${i}.txt
        [ -e ${i}.zip ] && rm ${i}.zip
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
        rm ${i}.zip
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