PROJECT     = awsday
ENV         = lab
SERVICE     = gitops

AWS_REGION  = us-east-1
DOCKER_UID  = $(shell id -u)
DOCKER_GID  = $(shell id -g)
DOCKER_USER = $(shell whoami)
AWS_ACCOUNT = $(shell aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION = 1.25

# create container base images
base:
	@docker build -t ${PROJECT}-${ENV}:base -f docker/base/Dockerfile .
	@docker build -t ${PROJECT}-${ENV}:golang-build --build-arg IMG=${PROJECT}-${ENV}:base -f docker/golang/build/Dockerfile .
	@docker build -t ${PROJECT}-${ENV}:python-build --build-arg IMG=${PROJECT}-${ENV}:base -f docker/python/build/Dockerfile .

# compiling golang application
golang-build:
	@echo '${DOCKER_USER}:x:${DOCKER_UID}:${DOCKER_GID}::/app:/sbin/nologin' > passwd
	@docker run --rm -u ${DOCKER_UID}:${DOCKER_GID} -v ${PWD}/passwd:/etc/passwd:ro -v ${PWD}/app/golang:/app ${PROJECT}-${ENV}:golang-build

# compiling python application
python-build:
	@echo '${DOCKER_USER}:x:${DOCKER_UID}:${DOCKER_GID}::/app:/sbin/nologin' > passwd
	@docker run --rm -u ${DOCKER_UID}:${DOCKER_GID} -v ${PWD}/passwd:/etc/passwd:ro -v ${PWD}/app/python:/app ${PROJECT}-${ENV}:python-build

# releasing new version of golang application
golang-release:
	$(eval TAG_RELEASE = $(shell cat app/golang/app.go | grep version | cut -d'"' -f8))
	@aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
	@docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-golang:${TAG_RELEASE} --build-arg IMG=${PROJECT}-${ENV}:base -f docker/golang/latest/Dockerfile .
	@docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-golang:${TAG_RELEASE}

# releasing new version of python application
python-release:
	$(eval TAG_RELEASE = $(shell cat app/python/app.py | grep version | cut -d'"' -f8))
	@aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
	@docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-python:${TAG_RELEASE} --build-arg IMG=${PROJECT}-${ENV}:base -f docker/python/latest/Dockerfile .
	@docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}-${ENV}-python:${TAG_RELEASE}

# creating registry for containers
registry:
	@cd terraform/registry/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve

# creating container cluster
cluster:
	@cd terraform/cluster/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_REGION}

# installing argocd in the cluster
argo-cd:
	@kubectl create namespace argocd
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# installing argocd in the cluster
argo-user:
	@echo " username: admin \n password: $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \n dns_name: $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}')"




































































# building codepipeline platform
codepipeline:
	@cd terraform/codepipeline/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve



# installing metrics server for containers
metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.2/components.yaml

# installing cluster autoscaler
cluster-autoscaler:
	@rm -rf /tmp/cluster-autoscaler-autodiscover.yaml
	@curl -s -L https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.25.0/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml -o /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|<YOUR CLUSTER NAME>|'${PROJECT}'-'${ENV}'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|1.22.2|'$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1)'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

# installing nginx ingress controller
ingress:
	@helm repo add nginx-stable https://helm.nginx.com/stable
	@helm repo update
	@helm install ingress-controller nginx-stable/nginx-ingress



















# capturing credentials from argocd
argo-auth:
	@echo -e " username: admin \n password: $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \n dns_name: $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

argo-app:
	@export CERT=$(shell aws acm list-certificates --query "CertificateSummaryList[*]|[?DomainName=='awsday.${AWS_DOMAIN}'].CertificateArn" --output text --region ${AWS_REGION}) && envsubst < argocd/guestbook.yaml | kubectl apply -f -





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
#	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
#	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve

# deleting temporary files
tmp:
	@rm -rf terraform/*/.terraform/
	@rm -rf terraform/*/.terraform.lock.hcl
	@rm -rf terraform/*/terraform.tfstate
	@rm -rf terraform/*/terraform.tfstate.backup
	@rm -rf app/golang/.cache
	@rm -rf app/golang/go.sum
	@rm -rf app/golang/run
	@rm -rf passwd
	@chmod 755 -R app/golang/go/ && rm -rf app/golang/go