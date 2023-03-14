SHELL:=/bin/bash

PROJECT            = gitops
ENV                = demo
EKS_VERSION        = 1.25
AWS_DEFAULT_REGION = us-east-1


## terraform

cluster:
	@cd terraform/cluster/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/cluster/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

certificate:
	@cd terraform/certificate/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/certificate/ && \
	  terraform apply -var="domain=${DOMAIN}" -auto-approve

route53:
	@cd terraform/certificate/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/route53/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -var="domain=${DOMAIN}" -auto-approve


## kubernetes

metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.2/components.yaml

cluster-autoscaler:
	@rm -rf /tmp/cluster-autoscaler-autodiscover.yaml
	@curl -s -L https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.25.0/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml -o /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|<YOUR CLUSTER NAME>|'${PROJECT}'-'${ENV}'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|1.22.2|'$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1)'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

argocd:
	@kubectl create namespace argocd
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@argocd login $(shell kubectl get service argocd-server -n argocd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo) --insecure


## guestbook

guestbook:
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-service.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-replica-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-replica-service.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/guestbook-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/guestbook-service.yaml
ifneq ($(strip $(DOMAIN)),)
	@rm -rf /tmp/guestbook-ssl.yaml
	@cp configs/guestbook-ssl.yaml /tmp/guestbook-ssl.yaml
	@sed -i 's|"elb-cert"|$(shell aws acm list-certificates --query 'CertificateSummaryList[?DomainName==`awsday.${DOMAIN}`].CertificateArn' --region ${AWS_DEFAULT_REGION} --output text)|g' /tmp/guestbook-ssl.yaml
	@sed -i 's|"elb-name"|${PROJECT}-${ENV}|g' /tmp/guestbook-ssl.yaml
	@kubectl apply -f /tmp/guestbook-ssl.yaml
else
	@kubectl apply -f configs/guestbook.yaml
endif


## accessories

clean:
	@rm -rf terraform/cluster/.terraform/
	@rm -rf terraform/cluster/.terraform.lock.hcl
	@rm -rf terraform/cluster/terraform.tfstate
	@rm -rf terraform/cluster/terraform.tfstate.backup
	@rm -rf terraform/certificate/.terraform/
	@rm -rf terraform/certificate/.terraform.lock.hcl
	@rm -rf terraform/certificate/terraform.tfstate
	@rm -rf terraform/certificate/terraform.tfstate.backup
	@rm -rf terraform/route53/.terraform/
	@rm -rf terraform/route53/.terraform.lock.hcl
	@rm -rf terraform/route53/terraform.tfstate
	@rm -rf terraform/route53/terraform.tfstate.backup

destroy:
	@kubectl delete service guestbook
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/certificate/ && \
	  terraform destroy -var="domain=${DOMAIN}" -auto-approve
#	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/route53/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -var="domain=${DOMAIN}" -auto-approve


## titan project

GIT_OWNER  = punkerside
GIT_REPO   = titan-bash
GIT_BRANCH = main
REP_HOME   = $(shell echo "$(shell pwd | rev | cut -d "/" -f1 | rev)")

# configurando directorio
ifeq ($(REP_HOME),${GIT_REPO})
GIT_HOME = $(shell echo "$(PWD)")
else
GIT_HOME = $(shell echo "$(PWD)/.${GIT_REPO}")
endif

init:
	@rm -rf .${GIT_REPO}/
	@git clone git@github.com:${GIT_OWNER}/${GIT_REPO}.git -b ${GIT_BRANCH} .${GIT_REPO}

# necesario para validaciones del repositorio titan
-include makefiles/*.mk

# necesario para la carga de procesos en repositorios clientes
-include .${GIT_REPO}/makefiles/*.mk