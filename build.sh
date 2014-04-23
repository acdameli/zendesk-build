#!/bin/bash

ZDUSER=""
ZDPASS=""
APP_ID=
ZIPFILE=app.zip
ZDSUBDOMAIN=""
ZAT=$(which zat)
ZIP=$(which zip)
NODE=$(which node)

function get_marker() {
 markers=( '/' '-' '\' '|' )
 echo ${markers[$(($1 % 4))]}
}

# validate the app using zat validate
if [ "zat not found" != $ZAT ]; then
 result=$(echo ""|$ZAT validate)

 if [ $? -eq 0 ]; then
  echo "successful zendesk validation"
 else
  echo "Failed validation. Exiting build:"
  echo "$result"
  exit
 fi
fi

echo "Zipping"
$ZIP -q -r "$ZIPFILE" . -x *.git -x *.DS_Store* -x build.sh

echo ""
echo "Uploading zip file"
UPLOAD=$(curl -s -u "$ZDUSER:$ZDPASS" -F uploaded_data=@$ZIPFILE -X POST https://$ZDSUBDOMAIN.zendesk.com/api/v2/apps/uploads.json)
UPLOAD_ID=$(node -pe 'JSON.parse(process.argv[1]).id' "$UPLOAD")

echo ""
echo "Associating upload with app: $APP_ID"
JOB=$(curl -s -u "$ZDUSER:$ZDPASS" -d '{"upload_id":"'$UPLOAD_ID'"}' -H "Content-Type: application/json" -X PUT https://$ZDSUBDOMAIN.zendesk.com/api/v2/apps/$APP_ID.json)
JOB_ID=$(node -pe 'JSON.parse(process.argv[1]).job_id' "$JOB")

echo ""
echo "Checking Build status"
while true; do
 BUILD=$(curl -s -u "$ZDUSER:$ZDPASS" -X GET https://$ZDSUBDOMAIN.zendesk.com/api/v2/apps/job_statuses/$JOB_ID.json 2> /dev/null)
 BUILD_STATUS=$(node -pe 'JSON.parse(process.argv[1]).status' "$BUILD")
 count=$(($count+1))
 marker=$(get_marker $count)

 if [ "$BUILD_STATUS" == "completed" ]; then
  echo ""
  echo "BUILD COMPLETE!"
  break
 else
  if [ "$BUILD_STATUS" == "failed" ]; then
   echo ""
   echo "BUILD FAILED!"
   break
  else
   printf "%s\r" "$marker : BUILD_STATUS = $BUILD_STATUS"
   sleep 1
  fi  
 fi  
done
