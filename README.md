# GitOps - Creating deployment pipelines with ArgoCD for Amazon EKS

[![Build](https://github.com/punkerside/awsday-demo/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/punkerside/awsday-demo/actions/workflows/main.yml)
[![Open Source Helpers](https://www.codetriage.com/punkerside/awsday-demo/badges/users.svg)](https://www.codetriage.com/punkerside/awsday-demo)
[![GitHub Issues](https://img.shields.io/github/issues/punkerside/awsday-demo.svg)](https://github.com/punkerside/awsday-demo/issues)
[![GitHub Tag](https://img.shields.io/github/tag-date/punkerside/awsday-demo.svg?style=plastic)](https://github.com/punkerside/awsday-demo/tags/)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/punkerside/awsday-demo)

<!-- <p align="center">
  <img src="docs/img/architecture.png">
</p> -->

## **Prerequisites**

* [Install Terraform](https://www.terraform.io/downloads.html)
* [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Install Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [Install Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

## **Resources**

### **1. Amazon AWS**

* [Virtual Private Cloud (VPC)](https://registry.terraform.io/modules/punkerside/vpc/aws/latest)
* [Elastic Container Service for Kubernetes (EKS)](https://registry.terraform.io/modules/punkerside/eks/aws/latest)

### **2. Kubernetes**

* [Argo CD](https://argoproj.github.io/cd)
* [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
* [Cluster Autoscaler (CA)](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
* [Guestbook](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/)

## **Containers**

| Name | Path | Runtime |
|------|------|--------|
| `movie` | `/movie` | python |
| `music` | `/music` | go |

## **Variables**

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `PROJECT` | Project's name | string | `gitops` | no |
| `ENV` | Environment Name | string | `demo` | no |
| `AWS_DEFAULT_REGION` | Amazon AWS Region | string | `us-east-1` | no |
| `EKS_VERSION` | Kubernetes version | string | `1.25` | no |
| `DOMAIN` | SSL for Guestbook | string | | no |

## **Base**

1. Create cluster

```bash
make cluster
```

2. Install **Metrics Server**

```bash
make metrics-server
```

3. Install **Cluster Autoscaler**

```bash
make cluster-autoscaler
```

4. Install **Argo CD**

```bash
make argocd
```

## **Opcional**

5. Deploy Guestbook application without SSL:

```bash
# deploy guestbook
make guestbook

# capture dns
kubectl get service --selector=app=guestbook
```

6. Deploy Guestbook application with SSL

```bash
# set domain
export DOMAIN=punkerside.io

# create ssl
make certificate

# deploy guestbook
make guestbook

# create dns
make route53
```

## **Release**

7. Create imagenes bases

```bash
make base
```

8. Compilando aplicaciones

```bash
make build
```

9. Compilando aplicaciones

```bash
make build
```