# homelab-platform

A GitOps-managed Kubernetes platform running in a homelab, built to mirror a production environment as closely as possible. The cluster runs **RKE2** on **vSphere** and is managed through **Rancher**, with workloads and platform services delivered by **Argo CD** and **Helm**.

## Purpose

This repo is a hands-on training ground for running Kubernetes the way it runs in production. It exists to:

- **Simulate production.** Use the same building blocks found in real environments: a hardened distribution (RKE2), central cluster management (Rancher), GitOps delivery, ingress, certificates, storage, and observability.
- **Practise day-to-day operations.** Deploy and upgrade applications, roll back bad releases, scale workloads, rotate certificates, manage RBAC and namespaces, and debug failing pods.
- **Practise day-2 operations.** Upgrade Kubernetes and Rancher, back up and restore etcd, replace or drain nodes, recover from failures, and tune resource usage.
- **Keep everything in Git.** Every change to the cluster goes through this repo, so the state of the platform is reviewable, repeatable and recoverable.

## Stack

| Layer | Tool |
| --- | --- |
| Hypervisor | VMware vSphere |
| Kubernetes distribution | RKE2 |
| Cluster management | Rancher |
| GitOps delivery | Argo CD |
| Packaging | Helm, Kustomize |
| Observability | Prometheus, Grafana, Loki, Alertmanager |

## Repository layout

```
.
├── apps/              # Application workloads deployed to the cluster (Helm values, manifests)
├── clusters/
│   └── platform/      # Cluster-specific config and Argo CD entry points for the platform cluster
├── infrastructure/    # Shared platform services: ingress, cert-manager, storage, monitoring, etc.
└── docs/              # Runbooks, architecture notes and day-2 procedures
```

- **`clusters/`** holds one directory per cluster. Each one points Argo CD at the infrastructure and apps that cluster should run.
- **`infrastructure/`** holds services the platform depends on. These are installed before applications.
- **`apps/`** holds the workloads that run on top of the platform.
- **`docs/`** holds runbooks for recurring tasks and incident recovery.

## How changes flow

1. Make a change on a branch (new app, updated Helm values, config tweak).
2. Open a pull request and review the diff.
3. Merge to `main`.
4. Argo CD detects the change and syncs it to the cluster.

Manual `kubectl apply` is reserved for break-glass situations. Anything changed by hand should be committed back to Git afterwards so the cluster and the repo stay in sync.

## Day-to-day activities to practise

**Workloads**
- Deploy a new application with Helm through Argo CD
- Roll out a new version and roll it back
- Configure resource requests, limits, HPAs and PodDisruptionBudgets
- Debug `CrashLoopBackOff`, `ImagePullBackOff` and `Pending` pods

**Platform**
- Manage namespaces, RBAC and service accounts
- Expose services through ingress with TLS from cert-manager
- Provision persistent volumes and test storage failover
- Build dashboards and alerts for cluster and app health

**Day-2 operations**
- Upgrade RKE2 and Rancher with minimal downtime
- Take and restore etcd snapshots
- Cordon, drain and replace nodes
- Rotate certificates and secrets
- Run failure drills and record them in `docs/`

## Secrets

Never commit plaintext secrets, kubeconfigs or tokens. Use an encrypted approach (for example Sealed Secrets or SOPS) and commit only the encrypted form. The `.gitignore` blocks common sensitive files, but it is a safety net, not a substitute for care.

## Getting started

Prerequisites on your workstation:

- `kubectl`
- `helm`
- `argocd` CLI
- Access to the Rancher UI and a kubeconfig for the cluster (kept outside this repo)

```bash
export KUBECONFIG=~/.kube/homelab-platform.yaml
kubectl get nodes
argocd app list
```
