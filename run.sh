#!/bin/bash

PROJECT="argocd"
ENV="lab"

AWS_DEFAULT_REGION="us-east-1"
AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION="1.27"
ECR_TOKEN=$(aws ecr --region=${AWS_DEFAULT_REGION} get-authorization-token --output text --query authorizationData[].authorizationToken | base64 -d | cut -d: -f2)

base () {
    export DOCKER_BUILDKIT=0
    docker build -t ${PROJECT}-${ENV}:base -f docker/base/Dockerfile .
}

cluster () {
    # inicializando terraform
    cd terraform/ && terraform init

    # creando cluster
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
	terraform apply -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

    # actualizando kubeconfig
	aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}
}

build () {
    SERVICE=$1

    export DOCKER_BUILDKIT=0
    docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:latest --build-arg IMG=${PROJECT}-${ENV}:base -f docker/${SERVICE}/Dockerfile .
}

release () {
    SERVICE=$1
    TAG_RELEASE=$(cat app/${SERVICE}/app.* | grep version | cut -d'"' -f8)
    TAG_IMMUTABLE=$(aws ecr describe-images --repository-name ${PROJECT}-${ENV}-${SERVICE} --region ${AWS_DEFAULT_REGION} | jq -r .imageDetails[].imageTags[] | grep "${TAG_RELEASE}")

    # validando ultima version publicada
    if [ "${TAG_IMMUTABLE}" = "${TAG_RELEASE}" ]
    then
      echo "the image tag ${TAG_RELEASE} already exists in the ${PROJECT}-${ENV}-${SERVICE} repository"
      exit 0
    fi

    # publicando nueva version
    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

}

destroy () {
    # destruyendo cluster
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
	cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

    # actualizando kubeconfig
	aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}
}

"$@"