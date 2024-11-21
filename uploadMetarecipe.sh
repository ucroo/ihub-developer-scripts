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
  echo "This is not a metarecipe, please use uploadRecipe.sh"
else
   for i in $CHILD_RECIPES; do
   uploadRecipe.sh "$i" "$ENVIRONMENT" || true
   done
   uploadRecipe.sh "$METARECIPE" "$ENVIRONMENT" || true
   printf "\n\nUploading to %s complete. Included recipes:\n - Parent recipe: %s\n" $ENVIRONMENT $METARECIPE
   for i in $CHILD_RECIPES; do
   echo " - Child recipe: " $i
   done
fi

#$CHILDREN=$(jq -r '.' <<<"$BINDINGS")
#echo $CHILDREN

#uploadRecipe.sh "$RECIPE_FAMILY" "$ENV" || true
