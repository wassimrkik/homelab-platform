# Helm basics: ingress-nginx by hand (PLAT-1)

Hands-on notes from installing, upgrading, rolling back and uninstalling
`ingress-nginx` with Helm on the `platform` cluster, before moving to GitOps.

- Chart: `ingress-nginx/ingress-nginx` 4.15.1 (app 1.15.1)
- Release name: `ingress-nginx`, namespace `ingress-nginx`
- Values: [`infrastructure/ingress-nginx/values.yaml`](../../infrastructure/ingress-nginx/values.yaml)

## Workflow

```bash
# 1. Find and inspect the chart
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx | less          # read defaults, never copy them wholesale
helm show readme ingress-nginx/ingress-nginx | grep limits    # key reference table

# 2. Render and check before installing
helm template ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
  -f infrastructure/ingress-nginx/values.yaml > /tmp/rendered.yaml
grep "replicas:" /tmp/rendered.yaml
helm template ... --show-only templates/controller-service.yaml | kubectl apply --dry-run=server -f -

# 3. Install
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f infrastructure/ingress-nginx/values.yaml
helm get values ingress-nginx -n ingress-nginx        # only my overrides
helm get values ingress-nginx -n ingress-nginx --all  # fully merged values

# 4. Upgrade (replicaCount 2 -> 3), inspect, roll back
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f infrastructure/ingress-nginx/values.yaml
helm history ingress-nginx -n ingress-nginx
helm rollback ingress-nginx 1 -n ingress-nginx

# 5. Inspect stored release state
kubectl -n ingress-nginx get secrets -l owner=helm --show-labels
kubectl -n ingress-nginx get secret sh.helm.release.v1.ingress-nginx.v3 \
  -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip | jq '.info, .config'

# 6. Remove everything
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

`helm install` syntax is `helm install <release-name> <chart> [flags]`. My failed
attempts were missing one of those pieces: no release name, a bare `ingress-nginx`
instead of the repo-qualified chart `ingress-nginx/ingress-nginx`, or no `-n`
(which installs into whatever namespace the current context points at).

## Values decisions

| Key | Value | Why |
| --- | --- | --- |
| `controller.replicaCount` | `2` | Survives a node drain. With >1 replica the chart also creates a PodDisruptionBudget (`minAvailable: 1`), so maintenance can evict one pod while the other keeps serving. |
| `controller.service.type` | `NodePort` | The default `LoadBalancer` would stay `<pending>` until MetalLB exists (Stage 3). |
| `controller.resources.requests` | `100m` CPU / `128Mi` | Guarantees scheduling and a fair CPU share under contention. |
| `controller.resources.limits.memory` | `512Mi` | Contains a memory leak to this pod instead of the node's OOM killer picking victims. |
| CPU limit | none, on purpose | The chart maintainers advise against it for this component ("Ideally, there should be no limits"). The controller carries all inbound traffic, and a CPU limit throttles it at peak load, causing timeouts for every app behind it even when the node has idle CPU. The CPU request already protects neighbours. |

Gotchas met while writing the values file:

- `controller.replicas` is not a key in this chart (`controller.replicaCount` is). Helm ignores unknown keys silently, so the typo rendered `replicas: 1` with no warning. Always check the rendered output.
- `type: nodePort` rendered fine but the API server rejected it (`Unsupported value: "nodePort"`). Kubernetes values are case-sensitive, and Helm doesn't validate them. Each layer catches different mistakes: render, then grep the output, then server-side dry run, then install.

## Questions

### 1. `helm install` vs `helm upgrade --install`: which in automation, and why?

`helm upgrade --install`. It's idempotent: it installs the release if it doesn't
exist and upgrades it if it does, so the same command is safe to run on every
pipeline execution. `helm install` fails with "cannot re-use a name that is still
in use" the second time, which makes it unsuitable for anything run repeatedly.

### 2. What happens to resources removed from a chart's templates on the next upgrade?

Helm deletes them. On upgrade, Helm compares the manifest stored in the previous
release with the newly rendered one, and anything that disappeared is removed
from the cluster. The exception is a resource annotated
`helm.sh/resource-policy: keep`, which Helm leaves in place (commonly used for PVCs
so data isn't deleted). This is also why resources created by hand are invisible to
Helm: they were never in a release manifest, so Helm neither updates nor removes them.

### 3. Why does a rollback create a new revision instead of going back?

A rollback re-applies an older revision's values and manifest as a new revision.
My history after `helm rollback ingress-nginx 1` was:

| Revision | Status | Description |
| --- | --- | --- |
| 1 | superseded | Install complete |
| 2 | superseded | Upgrade complete (replicaCount 3) |
| 3 | deployed | Rollback to 1 |

History is append-only, so it stays a full audit trail: you can see that revision 2
happened and was rolled back, and you can roll forward to it again if needed.
Rewinding would erase that record.

### 4. Where is release state stored, and what's the security implication?

In Secrets in the release's namespace, one per revision, named
`sh.helm.release.v1.<release>.v<revision>` and labelled `owner=helm`. The
`release` field is base64 (Kubernetes) of base64 (Helm) of gzipped JSON, which is
encoding, not encryption. Decoded, it contains the full chart, the rendered
manifest, and `config`: every value passed at install or upgrade.

Implication: any value passed to Helm, such as `--set db.password=...`, is stored in
plain-recoverable form in every revision kept (10 by default, `--history-max`),
readable by anyone with `get` or `list` on Secrets in that namespace. Sensitive
values should therefore live in real Secret objects (Sealed Secrets in Stage 3) that
the chart references, not be passed as Helm values. It's also one more reason RBAC
access to Secrets must be tightly restricted.

## Things I learned along the way

- A NodePort opens on every node. The ESXi1 worker answered on the controller's
  NodePort even though no controller pod ran there, because kube-proxy forwarded the
  traffic (`externalTrafficPolicy: Cluster`). Convenient, but it adds a hop and hides
  the client IP; `Local` keeps the client IP but only answers on nodes running a pod.
- ingress-nginx doesn't send traffic through the backend Service's ClusterIP. It
  reads the EndpointSlice and proxies straight to pod IPs (visible as `upstream=` in
  the controller log). The Service is still required: it's how nginx finds the pods.
- An Ingress backend must reference the Service `port`, not the container port.
  ingress-nginx tolerated a mismatch by also matching `targetPort`, but other
  controllers wouldn't. Naming the port (`name: http`) avoids the problem; the test
  app in `apps/hello/` does that.
- Two different 404s: an unknown host gets a 404 from the controller itself (no rule
  matched), while an unknown path on a matched host gets a 404 from the app (the
  controller log shows an `upstream=` pod IP).
- `.local` hostnames cost 5 seconds per connection on macOS, because the IPv6 lookup
  falls through to mDNS when `/etc/hosts` has no IPv6 entry. Use `.lab` or
  `.home.arpa` for internal names.
