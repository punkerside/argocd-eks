SHELL:=/bin/bash

PROJECT     = awsday
ENV         = lab
SERVICE     = gitops

AWS_REGION  = us-east-1
AWS_DOMAIN  = punkerside.io
DOCKER_UID  = $(shell id -u)
DOCKER_GID  = $(shell id -g)
DOCKER_WHO  = $(shell whoami)
AWS_ACCOUNT = $(shell aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION = 1.25

# creating registry for containers
registry:
	@cd terraform/registry/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="service=${SERVICE}" -auto-approve

# creating ssl certificates
certificate:
	@cd terraform/certificate/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/certificate/ && \
	  terraform apply -var="domain=${AWS_DOMAIN}" -auto-approve

# building codepipeline platform
codepipeline:
	@cd terraform/codepipeline/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="service=${SERVICE}" -auto-approve

# create container base images
base:
	docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:base -f docker/base/Dockerfile .
	docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:go-build --build-arg IMG=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:base -f docker/go-build/Dockerfile .

# build test applications
build:
	@echo '${DOCKER_WHO}:x:${DOCKER_UID}:${DOCKER_GID}::/app:/sbin/nologin' > passwd
	@docker run --rm -u ${DOCKER_UID}:${DOCKER_GID} -v ${PWD}/passwd:/etc/passwd:ro -v ${PWD}/app/music:/app ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:go-build

# releasing new versions of test applications
release:
	@aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
	@docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:python --build-arg IMG=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:base -f docker/python/Dockerfile .
	@docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:go --build-arg IMG=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:base -f docker/go/Dockerfile .
	$(eval TAG_PYTHON = $(shell cat app/movie/app.py | grep version | cut -d'"' -f8))
	$(eval TAG_GO = $(shell cat app/music/app.go | grep version | cut -d'"' -f8))
	@docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:python-${TAG_PYTHON}
	@docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-${SERVICE}:go-${TAG_GO}

# deleting infrastructure
destroy:
#	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="service=${SERVICE}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="service=${SERVICE}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/certificate/ && \
	  terraform destroy -var="domain=${AWS_DOMAIN}" -auto-approve
#	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/route53/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="domain=${AWS_DOMAIN}" -auto-approve



















# starting application locally
start:
	@export AWS_ACCOUNT=${AWS_ACCOUNT} && \
	  export AWS_DEFAULT_REGION=${AWS_REGION} && \
	  export PROJECT=${PROJECT} && \
	  export ENV=${ENV} && \
	  export SERVICE=${SERVICE} && \
	  docker-compose up

# stopping application locally
stop:
	@export AWS_ACCOUNT=${AWS_ACCOUNT} && \
	  export AWS_DEFAULT_REGION=${AWS_REGION} && \
	  export PROJECT=${PROJECT} && \
	  export ENV=${ENV} && \
	  export SERVICE=${SERVICE} && \
	  docker-compose down


























# creating container cluster
cluster:
	@cd terraform/cluster/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="service=${SERVICE}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV}-${SERVICE} --region ${AWS_REGION}

# installing metrics server for containers
metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.2/components.yaml

# installing cluster autoscaler
cluster-autoscaler:
	@rm -rf /tmp/cluster-autoscaler-autodiscover.yaml
	@curl -s -L https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.25.0/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml -o /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|<YOUR CLUSTER NAME>|'${PROJECT}'-'${ENV}'-'${SERVICE}'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|1.22.2|'$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1)'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

# installing argocd in the cluster
argocd:
	@kubectl create namespace argocd
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
#	@argocd login $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo) --insecure


# deleting temporary files
tmp:
	@rm -rf terraform/*/.terraform/
	@rm -rf terraform/*/.terraform.lock.hcl
	@rm -rf terraform/*/terraform.tfstate
	@rm -rf terraform/*/terraform.tfstate.backup
	@rm -rf app/music/.cache
	@rm -rf app/music/go.sum
	@rm -rf app/music/run
	@rm -rf passwd
	@chmod 755 app/music/go/ && rm -rf app/music/go















route53:
	@cd terraform/certificate/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/route53/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="domain=${DOMAIN}" -auto-approve















