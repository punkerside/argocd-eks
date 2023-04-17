# ArgoCD - Infrastructure

## **Variables**

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `PROJECT` | Project's name | string | `gitops` | no |
| `ENV` | Environment Name | string | `demo` | no |
| `AWS_REGION` | Amazon AWS Region | string | `us-east-1` | no |
| `EKS_VERSION` | Kubernetes version | string | `1.25` | no |

## **Usage**

1. Create VPC and EKS cluster.

```bash
make cluster
```

2. Create repositories for containers.

```bash
make registry
```

3. Create CI pipelines with AWS CodePipeline.

```bash
make codepipeline
```

4. Installing ArgoCD on the EKS cluster.

```bash
make argocd
```

- Capture logs of the ArgoCD Controller.

```bash
kubectl -n argocd logs -f --selector app.kubernetes.io/name=argocd-application-controller
```

- Capture logs of the Image Updater functionality.

```bash
kubectl -n argocd logs -f --selector app.kubernetes.io/name=argocd-image-updater
```

5. Deploying demo applications in EKS cluster with ArgoCD.

```bash
make apps
```