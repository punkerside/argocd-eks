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
<!-- 
## **Applications**

| App Name | App Code | App Manifest | Argo Manifest | App Language | Argo Trigger | Api App |
|----------|----------|--------------|---------------|--------------|--------------|---------|
| `cluster` | | `helm/cluster/` | `argo/cluster.yaml` | `yaml` | `gitops` | |
| `movie` | `app/python/` | `manifest/python/` | `argo/python.yaml` | `python` | `gitops` | `/movie` |
| `music` | `app/golang/` | `helm/golang/` | `argo/golang.yaml` | `golang` |`updater` | `/music` | -->

## **Usage**

| Demo | App | Docs |
|------|-----|------|
| `infrastructure` | `cluster` | [docs/infrastructure.md](docs/infrastructure.md) |
| `gitops` | `movie` | [docs/gitops.md](docs/gitops.md) |
| `updater` | `music` | [docs/updater.md](docs/updater.md) |



















<!-- 6. Running tests against demo applications.

- Creating container for tests

```bash
kubectl run -i --tty bash --image=alpine -- sh
# apk add curl
```

- Movie microservice.

```bash
# put data
curl -XPOST http://python.default.svc.cluster.local/movie/api?name=everest
# get data
curl http://python.default.svc.cluster.local/movie/api
# get version
curl http://python.default.svc.cluster.local/movie
```

- Music microservice.

```bash
# put data
curl -XPOST http://golang.default.svc.cluster.local/music/post?name=moby
# get data
curl http://golang.default.svc.cluster.local/music/get
# get version
curl http://golang.default.svc.cluster.local/music
``` -->

## **Author**

The demo is maintained by [Ivan Echegaray](https://github.com/punkerside)