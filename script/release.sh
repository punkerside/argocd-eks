#!/bin/bash

TAG_RELEASE=$(cat app/${SERVICE}/app.* | grep version | cut -d'"' -f8)
TAG_IMMUTABLE=$(aws ecr describe-images --repository-name $PROJECT-$ENV-$SERVICE --region $AWS_REGION | jq -r .imageDetails[].imageTags[] | grep "$TAG_RELEASE")

if [ "$TAG_IMMUTABLE" = "$TAG_RELEASE" ]
then
  echo "the image tag $TAG_RELEASE already exists in the $PROJECT-$ENV-$SERVICE repository"
  exit 0
fi

echo "TAG_RELEASE=$TAG_RELEASE"
echo "TAG_IMMUTABLE=$TAG_IMMUTABLE"

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:${TAG_RELEASE} --build-arg IMG=${PROJECT}-${ENV}:base -f docker/${SERVICE}/latest/Dockerfile .
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:${TAG_RELEASE}
