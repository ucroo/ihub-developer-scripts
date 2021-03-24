#!/bin/sh
ENV_SET=$1
if [ -z "$ENV_SET" ];
then
echo "please provide an environment set for this republish.  it should be either upper or lower"
exit 1
fi

for ENV in $(cat $ENV_SET)
do
  source uploadSharedConfig.sh $ENV $ENV
  source uploadFlow.sh $ENV $ENV
  source uploadTrigger.sh $ENV $ENV
done
