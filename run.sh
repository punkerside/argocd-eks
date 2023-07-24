#!/bin/bash

PROJECT="argocd"
ENV="lab"

AWS_DEFAULT_REGION="us-east-1"
AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION="1.27"
ECR_TOKEN=$(aws ecr --region=${AWS_DEFAULT_REGION} get-authorization-token --output text --query authorizationData[].authorizationToken | base64 -d | cut -d: -f2)

base () {
    export DOCKER_BUILDKIT=0
    docker build -t ${PROJECT}-${ENV}:base -f docker/Dockerfile.base .
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

destroy () {
    # destruyendo cluster
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
	cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

    # actualizando kubeconfig
	aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}
}

build () {
    SERVICE=$1
    base

    export DOCKER_BUILDKIT=0
    docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:latest --build-arg IMG=${PROJECT}-${ENV}:base -f docker/Dockerfile.${SERVICE} .
}

release () {
    SERVICE=$1
    TAG_RELEASE=$(cat app/${SERVICE}/app.* | grep version | cut -d'"' -f8)
    TAG_IMMUTABLE=$(aws ecr describe-images --repository-name ${PROJECT}-${ENV}-${SERVICE} --region ${AWS_DEFAULT_REGION} | jq -r .imageDetails[].imageTags[] | grep "${TAG_RELEASE}")

    # validando ultima version publicada
    if [ "${TAG_IMMUTABLE}" = "${TAG_RELEASE}" ]
    then
      echo -ne "\e[43m[WARNING]\e[0m The image tag ${TAG_IMMUTABLE} already exists in the argocd-lab-${SERVICE} repository \e[0m\n"
      exit 0
    fi

    # publicando nueva version
    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

    # etiquetando imagen
    docker tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:latest ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:${TAG_RELEASE}

    # publicando imagen
    docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:latest
    docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:${TAG_RELEASE}
}

argocd () {
    # preparando cluster
    kubectl create namespace argocd
    kubectl create -n argocd secret docker-registry pullsecret --docker-username=AWS --docker-password=${ECR_TOKEN} --docker-server="https://${AWS_ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"

    # instalando
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

    # esperando al servicio
    sleep 30s

    # capturando credenciales
    echo -e "\n username: admin \n password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \n dns_name: $(kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}')\n"

    # configurando argocd
    kubectl apply -n argocd -f manifest/kubectl/argocd/argocd-cm.yaml
}

apps () {
    # # instalando aplicacion para administrar cluster con gitops
    # export NAME=${PROJECT}-${ENV} VERSION=v$(curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep ${EKS_VERSION} | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < manifest/argocd/cluster.yaml | kubectl apply -f -

    # instalando aplicacion demo administrada por gitops
    kubectl apply -f manifest/argocd/gitops.yaml

    #  # instalando aplicacion demo administrada por image-updater
    # export NAME=golang PROJECT=${PROJECT} ENV=${ENV} AWS_ACCOUNT=${AWS_ACCOUNT} AWS_REGION=${AWS_REGION} && envsubst < manifest/deploy/main.yaml | kubectl apply -f -
}

"$@"