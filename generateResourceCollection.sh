#!/bin/bash

## usage -
## $1 is the directory to be combined ( ./build ) 
## $2 is the output directory ( ./build_student-grades )
## $3 is the collectionId of the app ( student-grades )
## $4 is the optional description
## $5 is the optional name
## $6 is the optional image

ROOT_DIR="$1"
OUTPUT_DIR="$2"
NAME="$3"

DESCRIPTION="$4"
APP_NAME="$5"
APP_IMAGE="$6"

case $# in
  3)
	echo "constructing resource around:\nROOT_DIR: $ROOT_DIR\nOUTPUT_DIR: $OUTPUT_DIR\nID: $NAME"
    ;;
  4)
	echo "constructing resource around:\nROOT_DIR: $ROOT_DIR\nOUTPUT_DIR: $OUTPUT_DIR\nID: $NAME\nDESCRIPTION: $DESCRIPTION"
    ;;
  5)
	echo "constructing resource around:\nROOT_DIR: $ROOT_DIR\nOUTPUT_DIR: $OUTPUT_DIR\nID: $NAME\nDESCRIPTION: $DESCRIPTION\nNAME: $APP_NAME"
    ;;
  6)
	echo "constructing resource around:\nROOT_DIR: $ROOT_DIR\nOUTPUT_DIR: $OUTPUT_DIR\nID: $NAME\nDESCRIPTION: $DESCRIPTION\nNAME: $APP_NAME\nIMAGE: $APP_IMAGE"
    ;;
  *)
    echo "not enough arguments supplied.  You must supply the source-directory, the target directory, and the collectionId to the command."
	echo "eg: \n generateResourceCollection.sh build student-grades-output student-grades"
	echo "you may optionally add 3 more arguments - the description of the resourceCollection, the name of the resourceCollection, and a url for the image of the resourceCollection"
    exit 1
    ;;
esac


rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
FILES_OUT="files"
mkdir -p "$OUTPUT_DIR/$FILES_OUT"

MANIFEST_FILE="$OUTPUT_DIR/manifest.json"

echo "{" > $MANIFEST_FILE
echo "\"collectionId\":\"$NAME\"," >> $MANIFEST_FILE
echo "\"name\":\"$APP_NAME\"," >> $MANIFEST_FILE
echo "\"description\":\"$DESCRIPTION\"," >> $MANIFEST_FILE
echo "\"image\":\"$IMAGE\"," >> $MANIFEST_FILE
echo "\"resources\":[" >> $MANIFEST_FILE

function uploadDir {
	dirName=$1
	echo "uploadingDir $dirName"
	awkCmd="{split(\$0, a, \"$ROOT_DIR/\"); print a[2]}"
	## echo "awkCmd $awkCmd"
    link=`awk "$awkCmd" <<< $dirName`
	targetDir="$OUTPUT_DIR/$FILES_OUT/$link"
	if [ -d "$targetDir" ];
	then
		echo "creating directory $targetDir"
	else
		mkdir -p $targetDir
	fi
	## echo "searching $dirName"
    for file in $dirName/*
    do
    ##    echo "FILE $file"
        if [ -d "$file" ]
        then
            uploadDir $file
        else
            uploadFile $file
        fi
    done
}

function uploadFile {
    file=$1
	echo "adding $file to manifest"
    awkCmd="{split(\$0, a, \"$ROOT_DIR/\"); print a[2]}"
##	echo "awkCmd $awkCmd"
    link=`awk "$awkCmd" <<< $file`
## echo "uploading file link $link"
	resourceId="${link}_${NAME}"
	resourceStatusCode=200 
	resourceAccessorMethod="GET" 
	resourceAccessorPath="/widgets/${NAME}/${link}"
	resourceDescription="" # get this from somewhere as an override maybe?
	resourceStateful="false"
	
	echo "copying file $file => $OUTPUT_DIR/$FILES_OUT/$link"
	cp $file "$OUTPUT_DIR/$FILES_OUT/$link"

	echo "{" >> $MANIFEST_FILE
	echo "\"resourceId\":\"$resourceId\"," >> $MANIFEST_FILE
	echo "\"resourceStatusCode\":$resourceStatusCode," >> $MANIFEST_FILE
	echo "\"resourceAccessorMethod\":\"$resourceAccessorMethod\"," >> $MANIFEST_FILE
	echo "\"resourceAccessorPath\":\"$resourceAccessorPath\"," >> $MANIFEST_FILE
	echo "\"resourceDescription\":\"$resourceDescription\"," >> $MANIFEST_FILE
	echo "\"resourceStateful\":$resourceStateful," >> $MANIFEST_FILE
	echo "\"resourcePath\":\"$FILES_OUT/$link\"," >> $MANIFEST_FILE
	echo "\"resourceHeaders\":[" >> $MANIFEST_FILE
	
	case "${link##*.}" in
        json)
			echo "[\"Content-Type\",\"application/json\"]" >> $MANIFEST_FILE
            ;;
        xml)
			echo "[\"Content-Type\",\"application/xml\"]" >> $MANIFEST_FILE
            ;;
        txt)
			echo "[\"Content-Type\",\"text/plain\"]" >> $MANIFEST_FILE
            ;;
        png)
			echo "[\"Content-Type\",\"image/png\"]" >> $MANIFEST_FILE
            ;;
        jpeg)
			echo "[\"Content-Type\",\"image/jpeg\"]" >> $MANIFEST_FILE
            ;;
        jpg)
			echo "[\"Content-Type\",\"image/jpeg\"]" >> $MANIFEST_FILE
            ;;
        htm)
			echo "[\"Content-Type\",\"text/html\"]" >> $MANIFEST_FILE
            ;;
        html)
			echo "[\"Content-Type\",\"text/html\"]" >> $MANIFEST_FILE
            ;;
        css)
			echo "[\"Content-Type\",\"text/css\"]" >> $MANIFEST_FILE
            ;;
        js)
			echo "[\"Content-Type\",\"text/javascript\"]" >> $MANIFEST_FILE
            ;;
        svg)
			echo "[\"Content-Type\",\"image/svg+xml\"]" >> $MANIFEST_FILE
            ;;
        *)
            ;;
    esac


	echo "]" >> $MANIFEST_FILE
	echo "}," >> $MANIFEST_FILE
}
uploadDir $ROOT_DIR
echo "]" >> $MANIFEST_FILE
echo "}" >> $MANIFEST_FILE
