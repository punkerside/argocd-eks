#!/bin/bash

DOCKER_UID=$(id -u)
DOCKER_GID=$(id -g)
DOCKER_USER=$(whoami)

TAG_RELEASE=$(cat app/${SERVICE}/app.* | grep version | cut -d'"' -f8)
TAG_IMMUTABLE=$(aws ecr describe-images --repository-name $PROJECT-$ENV-$SERVICE --region $AWS_REGION | jq -r .imageDetails[].imageTags[] | grep "$TAG_RELEASE")

if [ "$TAG_IMMUTABLE" = "$TAG_RELEASE" ]
then
  echo "the image tag $TAG_RELEASE already exists in the $PROJECT-$ENV-$SERVICE repository"
  exit 0
fi

# base
docker build -t $PROJECT-$ENV:base -f docker/base/Dockerfile .
docker build -t $PROJECT-$ENV:$SERVICE --build-arg IMG=$PROJECT-$ENV:base -f docker/$SERVICE/build/Dockerfile .

# build
echo ''$DOCKER_USER':x:'$DOCKER_UID':'$DOCKER_GID'::/app:/sbin/nologin' > passwd
docker run --rm -u $DOCKER_UID:$DOCKER_GID -v $PWD/passwd:/etc/passwd:ro -v $PWD/app/$SERVICE:/app $PROJECT-$ENV:$SERVICE

# release
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV-$SERVICE:$TAG_RELEASE --build-arg IMG=$PROJECT-$ENV:base -f docker/$SERVICE/latest/Dockerfile .
docker tag $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV-$SERVICE:$TAG_RELEASE $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV-$SERVICE:latest
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV-$SERVICE:$TAG_RELEASE
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT-$ENV-$SERVICE:latest
