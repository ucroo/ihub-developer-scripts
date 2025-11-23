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

CHILD_RECIPES=$(jq -r '.bindings | .. | select(type == "object" and has("recipeId") and .variableType == "recipeExecution") | .recipeId' $METARECIPE/metadata.json)

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
      [ -e "${i}.zip" ] && rm ${i}.zip
      zip -r ${i}.zip $i
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