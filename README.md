# homelab-platform

A GitOps-managed Kubernetes platform running in a homelab, built to mirror a production environment as closely as possible. The cluster runs **RKE2** on **vSphere** and is managed through **Rancher**, with workloads and platform services delivered by **Argo CD** and **Helm**.

## Purpose

This repo is a hands-on training ground for running Kubernetes the way it runs in production. It exists to:

- **Simulate production.** Use the same building blocks found in real environments: a security-focused distribution (RKE2; the CIS hardening profile is planned but not yet enabled), central cluster management (Rancher), GitOps delivery, ingress, certificates, storage, and observability.
- **Practise day-to-day operations.** Deploy and upgrade applications, roll back bad releases, scale workloads, rotate certificates, manage RBAC and namespaces, and debug failing pods.
- **Practise day-2 operations.** Upgrade Kubernetes and Rancher, back up and restore etcd, replace or drain nodes, recover from failures, and tune resource usage.
- **Keep everything in Git.** Every change to the cluster goes through this repo, so the state of the platform is reviewable, repeatable and recoverable.

## Stack

| Layer | Tool | Status |
| --- | --- | --- |
| Hypervisor | VMware vSphere (ESXi) | In place |
| Kubernetes distribution | RKE2 v1.36 | In place |
| CNI | Calico | In place |
| Cluster management | Rancher | In place |
| GitOps delivery | Argo CD | Planned |
| Packaging | Helm, Kustomize | Planned |
| Load balancer | MetalLB | Planned |
| Ingress | Installed by us (RKE2 built-in ingress disabled) | Planned |
| Certificates | cert-manager | Planned |
| Storage | Longhorn | Planned |
| Secrets | Sealed Secrets | Planned |
| Observability | Prometheus, Grafana, Loki, Alertmanager | Planned |

## Cluster layout

| Role | Count |
| --- | --- |
| Control plane (RKE2 server) | 1 |
| Worker (RKE2 agent) | 3 |

- **Hosts:** the 4 node VMs are spread across 2 ESXi hosts.
- **Kubernetes:** RKE2 v1.36
- **CNI:** Calico
- **Ingress:** RKE2's built-in ingress controller is disabled. We install and manage ingress ourselves from this repo.
- **CIS profile:** not enabled yet (planned).

With a single control plane node, the cluster is not highly available. Losing that node takes down the API server until it is restored from an etcd snapshot. That makes etcd backup and restore a key drill.

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

1. Create a branch per ticket, named `plat-N-short-name` (for example `plat-0-repo-structure`).
2. Make the change (new app, updated Helm values, config tweak).
3. Open a pull request with `Closes #N` in the **body** so the issue is linked and closed on merge.
4. Get the PR reviewed and approved.
5. Squash-merge to `main`.
6. Argo CD detects the change and syncs it to the cluster.

### Rules on `main`

- No direct pushes: every change goes through a pull request.
- Squash merge only, keeping history linear.
- The PR title becomes the commit message on `main`, so it must describe the change (for example `docs: add repo structure, README and .gitignore (PLAT-0)`).

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

Never commit plaintext secrets, kubeconfigs or tokens. Encrypt secrets with Sealed Secrets and commit only the encrypted form.

- Name encrypted secrets `*.sealed.yaml`. The `.gitignore` allows these even though it blocks `*-secret.yaml` and `*.secret.yaml`.
- The kubeseal public cert (`sealed-secrets/pub-cert.pem`) is safe to commit, because it can only encrypt.
- Public CA certificates (`*.crt`) are safe to commit. Private keys (`*.key`, `*.pem`) are blocked.

The `.gitignore` is a safety net, not a substitute for care. Check a new file with `git check-ignore -v <path>` if `git add` seems to skip it.

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
