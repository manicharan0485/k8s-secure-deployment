# 🔒 K8s Secure Deployment

> **Kubernetes security reference — RBAC, Network Policies, Pod Security, image scanning, and CI/CD DevSecOps pipeline.**  
> Helm charts + manifests that enforce security by default, not as an afterthought.

> 🧪 **Reference / lab project.** Original practice code written to demonstrate the approach. It is not taken from an employer's codebase. Review and adapt before using it in your own environment.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logo=aqua&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🎯 Security Features

| Layer | What's Enforced |
|-------|----------------|
| **RBAC** | Least-privilege roles per namespace, no cluster-admin for apps |
| **Network Policies** | Default-deny ingress+egress, explicit allow per service |
| **Pod Security** | Non-root, read-only filesystem, drop ALL capabilities |
| **Image Scanning** | Trivy in CI/CD — blocks deploy on CRITICAL/HIGH CVEs |
| **Secrets** | No plaintext secrets in manifests — sealed or external secrets |
| **Resource Limits** | CPU/memory limits on every container (DoS prevention) |
| **Admission Control** | OPA Gatekeeper policies for policy-as-code |

---

## 📂 Structure

```
k8s-secure-deployment/
│
├── helm/
│   ├── base/                      # Helm chart: secure app baseline
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # Secure defaults
│   │   └── templates/
│   │       ├── deployment.yaml    # Pod security context enforced
│   │       ├── service.yaml
│   │       ├── networkpolicy.yaml # Default deny + optional ingress/monitoring rules
│   │       └── rbac.yaml
│   └── overlays/
│       ├── dev/values.yaml
│       └── prod/values.yaml
│
├── manifests/
│   ├── rbac/
│   │   └── cluster-roles.yaml     # Read-only, developer, operator roles
│   ├── network-policies/
│   │   ├── default-deny-all.yaml  # Block all traffic by default
│   │   └── allow-dns.yaml         # Allow kube-dns
│   ├── pod-security/
│   │   └── gatekeeper-policies.yaml  # OPA Gatekeeper constraints
│   └── namespaces/
│       └── production.yaml
│
├── scripts/
│   ├── trivy-scan.sh              # Scan image + fail on HIGH/CRITICAL
│   └── rbac-audit.sh              # Check for overprivileged service accounts
│
├── .github/
│   └── workflows/
│       ├── security-scan.yml      # Trivy + Kubesec + Checkov on every PR
│       └── deploy.yml             # Deploy only if scans pass
│
└── monitoring/
    └── prometheus/                # Security-focused alerting rules
```

---

## 🚀 Quick Start

### 1. Apply security manifests to your cluster

```bash
# Create namespaces with Pod Security Standards
kubectl apply -f manifests/namespaces/

# Apply default-deny network policies
kubectl apply -f manifests/network-policies/default-deny-all.yaml
kubectl apply -f manifests/network-policies/allow-dns.yaml

# Apply RBAC
kubectl apply -f manifests/rbac/

# Verify
kubectl get networkpolicies -A
kubectl get rolebindings -A
```

### 2. Deploy a secure app with Helm

```bash
helm install my-app ./helm/base \
  --namespace production \
  --values helm/overlays/prod/values.yaml \
  --set image.repository=myrepo/myapp \
  --set image.tag=v1.2.0
```

### 3. Scan image before deploy

```bash
bash scripts/trivy-scan.sh myrepo/myapp:v1.2.0
# Exits with code 1 if CRITICAL or HIGH CVEs found
```

---

## 🛡️ Pod Security Context (All Deployments)

Every deployment enforces:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001           # Non-root UID
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]         # Drop ALL Linux capabilities
      privileged: false
```

---

## 🔐 RBAC Design

```
cluster-admin    → Infrastructure/SRE team only
cluster-viewer   → Read-only for all namespaces (auditors)
namespace-admin  → Full access within one namespace (team leads)
namespace-dev    → Deploy/manage pods, no RBAC changes
namespace-viewer → Read-only within namespace (monitoring)
```

---

## 🌐 Network Policy Strategy

Default posture: **deny all**. Explicit allow rules added per need.

```
Internet → Ingress Controller → [Service] → Pod  ✅ (Helm NetworkPolicy, allowIngressFromIngress)
Pod → Pod (same namespace)                        ❌ (blocked by default)
Pod → Pod (cross-namespace)                       ❌ (blocked by default)
Pod → kube-dns (53/UDP)                           ✅ (via allow-dns.yaml)
Prometheus → Pod (metrics port)                   ✅ (Helm NetworkPolicy, allowIngressFromMonitoring)
Pod → Internet (egress)                           ❌ (blocked by default — add explicit rule)
```

---

## 🔄 CI/CD Security Pipeline

Every PR triggers:
1. **Trivy** — container image vulnerability scan
2. **Kubesec** — Kubernetes manifest security scoring
3. **Checkov** — IaC security scanning (Helm/Terraform)
4. **Conftest** — OPA policy validation

Deploy only proceeds if all scans pass.

---

## 📄 License

MIT — Free to use and adapt.

---

## 👤 Author

**Manicharan Ravi** — IT Specialist & Cloud Engineer  
📍 Mainz, Germany | ☁️ Kubernetes · Docker · DevSecOps · Helm · Terraform  
🌐 [Portfolio](https://manicharan0485.github.io) · [LinkedIn](https://linkedin.com/in/manicharan-ravi)
## Additional controls

| Control | Location |
|---|---|
| Native CEL admission policy (no `:latest`, memory limits, read-only FS, no hostNetwork) | `manifests/admission-policy/validating-admission-policy.yaml` (Kubernetes 1.30+) |
| Kyverno: registry allow-list, cosign signature verification, no privileged/hostPath | `manifests/admission-policy/kyverno/policies.yaml` |
| Falco runtime rules | `runtime/falco-rules.yaml` |
| API server audit policy | `audit/audit-policy.yaml` |
| Local test cluster (kind, no default CNI) | `kind/kind-config.yaml` |
| Insecure pod demo and smoke tests | `examples/insecure-pod.yaml`, `scripts/verify.sh` |
| Full checklist | `docs/security-checklist.md` |

These manifests have not been run against a live cluster. Replace the `registry.example.com` and `YOUR_ORG/YOUR_REPO` placeholders and test in audit mode first.
