PROJECT     = awsday
ENV         = lab
SERVICE     = gitops

AWS_REGION  = us-east-1
DOCKER_UID  = $(shell id -u)
DOCKER_GID  = $(shell id -g)
DOCKER_USER = $(shell whoami)
AWS_ACCOUNT = $(shell aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION = 1.25

# creating container cluster
cluster:
	@cd terraform/cluster/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_REGION}

# creating registry for containers
registry:
	@cd terraform/registry/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve

# building codepipeline platform
codepipeline:
	@cd terraform/codepipeline/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve

# create container base images
base:
	@docker build -t ${PROJECT}-${ENV}:base -f docker/base/Dockerfile .
	@docker build -t ${PROJECT}-${ENV}:golang --build-arg IMG=${PROJECT}-${ENV}:base -f docker/golang/build/Dockerfile .
	@docker build -t ${PROJECT}-${ENV}:python --build-arg IMG=${PROJECT}-${ENV}:base -f docker/python/build/Dockerfile .

# build application
build:
	@echo '${DOCKER_USER}:x:${DOCKER_UID}:${DOCKER_GID}::/app:/sbin/nologin' > passwd
	@docker run --rm -u ${DOCKER_UID}:${DOCKER_GID} -v ${PWD}/passwd:/etc/passwd:ro -v ${PWD}/app/${SERVICE}:/app ${PROJECT}-${ENV}:${SERVICE}

# releasing new version of application
release:
	@export PROJECT=${PROJECT} && \
	export ENV=${ENV} && \
	export AWS_ACCOUNT=${AWS_ACCOUNT} && \
	export AWS_REGION=${AWS_REGION} && \
	${PWD}/script/release.sh

# installing argocd in the cluster
argocd:
	@kubectl create namespace argocd
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# getting argocd credentials
auth:
	@echo " username: admin \n password: $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \n dns_name: $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

apps:
	export NAME=${PROJECT}-${ENV} VERSION=v$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < manifest/cluster/main.yaml | kubectl apply -f -
#	export CERT=$(shell aws acm list-certificates --query "CertificateSummaryList[*]|[?DomainName=='awsday.${AWS_DOMAIN}'].CertificateArn" --output text --region ${AWS_REGION}) && envsubst < argocd/guestbook.yaml | kubectl apply -f -

























# starting application locally
start:
	@export AWS_ACCOUNT=${AWS_ACCOUNT} && \
	  export AWS_DEFAULT_REGION=${AWS_REGION} && \
	  export PROJECT=${PROJECT} && \
	  export ENV=${ENV} && \
	  docker-compose up

# stopping application locally
stop:
	@export AWS_ACCOUNT=${AWS_ACCOUNT} && \
	  export AWS_DEFAULT_REGION=${AWS_REGION} && \
	  export PROJECT=${PROJECT} && \
	  export ENV=${ENV} && \
	  docker-compose down

# deleting infrastructure
destroy:
#	@export NAME=${PROJECT}-${ENV} VERSION=v$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < argocd/cluster.yaml | kubectl delete -f -
#	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
#	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve

# deleting temporary files
tmp:
#	@rm -rf terraform/*/.terraform/
#	@rm -rf terraform/*/.terraform.lock.hcl
#	@rm -rf terraform/*/terraform.tfstate
#	@rm -rf terraform/*/terraform.tfstate.backup
	@rm -rf app/python/flask/app.py
	@cd app/python/ && find . ! -name app.py -delete
	@rm -rf app/golang/.cache
	@rm -rf app/golang/go.sum
	@rm -rf app/golang/run
	@rm -rf passwd
	@chmod 755 -R app/golang/go/ && rm -rf app/golang/go