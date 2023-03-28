#!/bin/bash

TAG_RELEASE=$(cat app/${SERVICE}/app.* | grep version | cut -d'"' -f8)
TAG_IMMUTABLE=$(aws ecr describe-images --repository-name $PROJECT-$ENV-$SERVICE --region $AWS_REGION | jq -r .imageDetails[].imageTags[] | grep "$TAG_RELEASE")

if [ "$TAG_IMMUTABLE" = "$TAG_RELEASE" ]
then
  echo "the image tag $TAG_RELEASE already exists in the $PROJECT-$ENV-$SERVICE repository"
  exit 0
fi

docker build -t $PROJECT-$ENV:base -f docker/base/Dockerfile .
docker build -t $PROJECT-$ENV:$SERVICE --build-arg IMG=$PROJECT-$ENV:base -f docker/$SERVICE/build/Dockerfile .
