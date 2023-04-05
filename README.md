# GitOps - Creating deployment pipelines with ArgoCD for Amazon EKS

[![Build](https://github.com/punkerside/awsday-demo/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/punkerside/awsday-demo/actions/workflows/main.yml)
[![Open Source Helpers](https://www.codetriage.com/punkerside/awsday-demo/badges/users.svg)](https://www.codetriage.com/punkerside/awsday-demo)
[![GitHub Issues](https://img.shields.io/github/issues/punkerside/awsday-demo.svg)](https://github.com/punkerside/awsday-demo/issues)
[![GitHub Tag](https://img.shields.io/github/tag-date/punkerside/awsday-demo.svg?style=plastic)](https://github.com/punkerside/awsday-demo/tags/)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/punkerside/awsday-demo)

<p align="center">
  <img src="docs/architecture.png">
</p>

## **Prerequisites**

* [Install Terraform](https://www.terraform.io/downloads.html)
* [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Install Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## **Resources**

### **1. Amazon AWS**

* [Virtual Private Cloud (VPC)](https://registry.terraform.io/modules/punkerside/vpc/aws/latest)
* [Elastic Container Service for Kubernetes (EKS)](https://registry.terraform.io/modules/punkerside/eks/aws/latest)

### **2. Kubernetes**

* [Argo CD](https://argoproj.github.io/cd)
* [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
* [Cluster Autoscaler (CA)](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)

## **Applications**

| Name | Path | Runtime | Trigger |
|------|------|---------|---------|
| `cluster` | | yaml | gitops |
| `movie` | `/movie` | python | gitops |
| `music` | `/music` | golang | image |

## **Variables**

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `PROJECT` | Project's name | string | `gitops` | no |
| `ENV` | Environment Name | string | `demo` | no |
| `AWS_REGION` | Amazon AWS Region | string | `us-east-1` | no |
| `EKS_VERSION` | Kubernetes version | string | `1.25` | no |

## **Usage**

1. Create Cluster

```bash
make cluster
```

2. Create Repositories

```bash
make registry
```

3. Create CodePipeline

```bash
make codepipeline
```

4. Install ArgoCD

```bash
make argocd
```

- Capture logs of the Image Updater functionality

```bash
kubectl -n argocd logs -f --selector app.kubernetes.io/name=argocd-image-updater
```

5. Deploy Apps

```bash
make apps
```

6. Testing Apps

- Creating container for tests

```bash
kubectl run -i --tty test --image=alpine -- sh
# apk add curl
```

- Testing the Movie microservice

```bash
# put data
curl -XPOST http://python.default.svc.cluster.local/movie/api?name=everest
# get data
curl http://python.default.svc.cluster.local/movie/api
# get version
curl http://python.default.svc.cluster.local/movie
```

- Testing the Music microservice

```bash
# put data
curl -XPOST http://golang.default.svc.cluster.local/music/post?name=moby
# get data
curl http://golang.default.svc.cluster.local/music/get
# get version
curl http://golang.default.svc.cluster.local/music
```