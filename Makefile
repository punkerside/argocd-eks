SHELL:=/bin/bash

PROJECT            = gitops
ENV                = demo
EKS_VERSION        = 1.25
AWS_DEFAULT_REGION = us-east-1
DOMAIN             = punkerside.io

cluster:
	@cd terraform/cluster/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/cluster/ && \
	  terraform apply -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

destroy:
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/cluster/ && \
	  terraform destroy -var="project=${PROJECT}" -var="env=${ENV}" -auto-approve
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/certificate/ && \
	  terraform destroy -var="domain=${DOMAIN}" -auto-approve | exit 0

metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.2/components.yaml

cluster-autoscaler:
	@rm -rf /tmp/cluster-autoscaler-autodiscover.yaml
	@curl -s -L https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.25.0/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml -o /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|<YOUR CLUSTER NAME>|'${PROJECT}'-'${ENV}'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@sed -i 's|1.22.2|'$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1)'|g' /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml
	@kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

certificate:
	@cd terraform/certificate/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/certificate/ && \
	  terraform apply -var="domain=${DOMAIN}" -auto-approve

guestbook:
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-service.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-replica-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-replica-service.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/guestbook-controller.yaml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/guestbook-service.yaml
	@kubectl apply -f configs/guestbook-service.yaml