#!/bin/bash
BUNDLE="$1"
ENVIRONMENT="$2"

require jq

case $# in
  2)
    ENVIRONMENT="$2"
    ;;
  1)
    ENVIRONMENT="local"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the bundle directory to this command."
    exit 1
    ;;
esac    

source setEnvForUpload.sh $ENVIRONMENT

safeName () {
	SAFE=$1
	SAFE=${SAFE//\_/_US_}
	SAFE=${SAFE//\*/_A_}
  SAFE=${SAFE//@/_AT_}
	SAFE=${SAFE//\\/_BS_}
	SAFE=${SAFE//\:/_CL_}
	SAFE=${SAFE//,/_CM_}
	SAFE=${SAFE//\^/_CT_}
	SAFE=${SAFE//\$/_D_}
	SAFE=${SAFE//\"/_DQ_}
	SAFE=${SAFE//\./_DT_}
	SAFE=${SAFE//>/_GT_}
	SAFE=${SAFE//#/_H_}
	SAFE=${SAFE//</_LT_}
	SAFE=${SAFE//|/_P_}
	SAFE=${SAFE//%/_PC_}
	SAFE=${SAFE//\?/_QM_}
	SAFE=${SAFE//\//_S_}
	SAFE=${SAFE// /_SP_}
	SAFE=${SAFE//\'/_SQ_}
	SAFE=${SAFE//\~/_T_}
	echo "$SAFE"
}
safeFileReference () {
	SAFE=$1
	SAFE=${SAFE//file:\/\/\.\//}
	echo "$SAFE"
}

SAFE_BUNDLE=$(safeName $BUNDLE)
rm ${SAFE_BUNDLE}.zip
REFS=$(cat ${SAFE_BUNDLE}.json | jq '.. |."fileReference"? | select(. != null)')
SAFE_REFS=""
for FR in $REFS;
do SAFE_REFS="$SAFE_REFS $(safeFileReference ${FR//\"/})"
done
zip -r ${SAFE_BUNDLE}.zip ${SAFE_BUNDLE}.json $SAFE_REFS

if [ -z $FLOW_TOKEN ] ;
then
	exit 1
else
	http_response=$(curl $CURL_ARGS -s -o uploadBundleResponse.txt -w "%{http_code}" -X POST -H "flow-token: $FLOW_TOKEN" -H "Content-Type: application/octet-stream" "$HOST/repository/bundles?format=flow-zip&id=$BUNDLE" --data-binary "@${SAFE_BUNDLE}.zip")
fi

if [ $http_response != "200" ];
then
  if [ $http_response == "302" ];
  then
    echo "Got unexpected HTTP response ${http_response}. This is likely due to your token being incorrect."
  else
    echo "Got unexpected HTTP response ${http_response}. This is likely an error."
		cat uploadBundleResponse.txt
  fi
else
  cat uploadBundleResponse.txt
fi

[ -e uploadBundleResponse.txt ] && rm uploadBundleResponse.txt
#rm ${SAFE_BUNDLE}.zip
