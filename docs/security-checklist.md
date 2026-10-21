# Production Kubernetes Security Checklist

## 1. Pod and container (Pod Security Standards: restricted)
- [ ] `runAsNonRoot: true`, explicit non-zero `runAsUser`
- [ ] `allowPrivilegeEscalation: false`
- [ ] `capabilities.drop: [ALL]`; add back only what is justified (e.g. `NET_BIND_SERVICE`)
- [ ] `readOnlyRootFilesystem: true` with `emptyDir` for writable paths
- [ ] `seccompProfile.type: RuntimeDefault`
- [ ] No `privileged`, `hostNetwork`, `hostPID`, `hostIPC`, `hostPath`
- [ ] `automountServiceAccountToken: false` unless the app calls the API
- [ ] CPU/memory requests and limits set

## 2. Namespace and cluster guardrails
- [ ] PSA labels: `enforce=restricted` on prod namespaces
- [ ] ValidatingAdmissionPolicy or Kyverno/Gatekeeper for org rules
- [ ] ResourceQuota + LimitRange per namespace

## 3. Network
- [ ] Default-deny ingress and egress, then explicit allows
- [ ] CNI that enforces NetworkPolicy (Calico, Cilium)
- [ ] Restrict egress to metadata endpoint (169.254.169.254) on cloud nodes
- [ ] TLS everywhere; consider mTLS via a service mesh

## 4. Identity and access
- [ ] RBAC least privilege; no wildcards; no routine `cluster-admin`
- [ ] Human access via OIDC/SSO groups, not static certs or tokens
- [ ] One ServiceAccount per workload
- [ ] Cloud IAM via workload identity (IRSA, GKE WI), not node-wide roles
- [ ] Audit who can `exec`, `create pods`, `impersonate`, `escalate`, `bind`

## 5. Secrets
- [ ] etcd encryption at rest (KMS provider preferred)
- [ ] External secrets manager (External Secrets Operator, CSI driver, Vault)
- [ ] No secrets in images, env files, or Git; scan with gitleaks/trufflehog
- [ ] Prefer mounted files over env vars; rotate regularly

## 6. Supply chain
- [ ] Minimal/distroless base images, pinned by digest
- [ ] Trivy/Grype scan in CI, fail on HIGH/CRITICAL fixable
- [ ] Sign images (cosign) and verify at admission
- [ ] SBOM generated and stored (syft)
- [ ] Only trusted registries allowed

## 7. Runtime and detection
- [ ] Falco or Tetragon for runtime alerts
- [ ] API server audit logging enabled, shipped off-cluster
- [ ] Alerts on exec into pods, RBAC changes, privileged pod attempts

## 8. Nodes and control plane
- [ ] CIS benchmark via kube-bench; fix FAILs
- [ ] Kubelet: anonymous auth off, `readOnlyPort: 0`, authorization Webhook
- [ ] API server not publicly exposed, or restricted by CIDR
- [ ] Node OS hardened and auto-patched; Kubernetes minor versions kept in support

## 9. Operations
- [ ] PodDisruptionBudgets, multiple replicas, topology spread
- [ ] Backups (etcd/Velero) tested by restore
- [ ] Incident runbook: isolate pod (label swap + deny NetworkPolicy), preserve evidence, rotate secrets
