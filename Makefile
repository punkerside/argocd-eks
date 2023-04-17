PROJECT     = awsday
ENV         = lab

AWS_REGION  = us-east-1
AWS_ACCOUNT = $(shell aws sts get-caller-identity --query "Account" --output text)
EKS_VERSION = 1.25
ECR_TOKEN   = $(shell aws ecr --region=${AWS_REGION} get-authorization-token --output text --query authorizationData[].authorizationToken | base64 -d | cut -d: -f2)

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

# installing argocd in the cluster
argocd:
	@kubectl create namespace argocd
	@kubectl create -n argocd secret docker-registry pullsecret   --docker-username=AWS   --docker-password=${ECR_TOKEN}   --docker-server="https://${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
	@echo "\n esperando creacion del balanceador" && sleep 20s
	@make initial

# getting argocd startup credentials
initial:
	@echo "\n username: admin \n password: $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \n dns_name: $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}')\n"

# deploying argocd applications
apps:
	@export NAME=${PROJECT}-${ENV} VERSION=v$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < manifest/cluster/main.yaml | kubectl apply -f -
	@kubectl apply -f manifest/gitops/main.yaml
	@export NAME=golang PROJECT=${PROJECT} ENV=${ENV} AWS_ACCOUNT=${AWS_ACCOUNT} AWS_REGION=${AWS_REGION} && envsubst < manifest/deploy/main.yaml | kubectl apply -f -

# releasing new version of application
release:
	@export PROJECT=${PROJECT} && export ENV=${ENV} && export SERVICE=${SERVICE} && export AWS_ACCOUNT=${AWS_ACCOUNT} && export AWS_REGION=${AWS_REGION} && ${PWD}/script/release.sh

# deleting infrastructure
destroy:
	@export NAME=golang PROJECT=${PROJECT} ENV=${ENV} AWS_ACCOUNT=${AWS_ACCOUNT} AWS_REGION=${AWS_REGION} && envsubst < argo/updater.yaml | kubectl delete -f -
	@kubectl delete -f argo/gitops.yaml
	@export NAME=${PROJECT}-${ENV} VERSION=v$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < argo/cluster.yaml | kubectl delete -f -
	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/codepipeline/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/registry/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

# deleting temporary files
tmp:
	@rm -rf terraform/*/.terraform/
	@rm -rf terraform/*/.terraform.lock.hcl
	@rm -rf terraform/*/terraform.tfstate
	@rm -rf terraform/*/terraform.tfstate.backup
	@rm -rf app/python/flask/app.py
	@cd app/python/ && find . ! -name app.py -delete
	@rm -rf app/golang/.cache
	@rm -rf app/golang/go.sum
	@rm -rf app/golang/run
	@rm -rf passwd
#	@chmod 755 -R app/golang/go/ && rm -rf app/golang/go