PROJECT            = gitops
ENV                = demo
AWS_DEFAULT_REGION = us-east-1

cluster:
	export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && \
	cd terraform/ && \
	  terraform init