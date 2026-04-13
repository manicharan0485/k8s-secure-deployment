# 🔒 K8s Secure Deployment

> **Production-grade Kubernetes security — RBAC, Network Policies, Pod Security, image scanning, and CI/CD DevSecOps pipeline.**  
> Helm charts + manifests that enforce security by default, not as an afterthought.

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
│   │       ├── serviceaccount.yaml
│   │       ├── networkpolicy.yaml
│   │       ├── rbac.yaml
│   │       └── hpa.yaml
│   └── overlays/
│       ├── dev/values.yaml
│       └── prod/values.yaml
│
├── manifests/
│   ├── rbac/
│   │   ├── cluster-roles.yaml     # Read-only, developer, operator roles
│   │   └── namespace-roles.yaml   # Per-namespace bindings
│   ├── network-policies/
│   │   ├── default-deny-all.yaml  # Block all traffic by default
│   │   ├── allow-dns.yaml         # Allow kube-dns
│   │   ├── allow-ingress.yaml     # Allow ingress controller → pods
│   │   └── allow-monitoring.yaml  # Allow Prometheus scraping
│   ├── pod-security/
│   │   ├── podsecurity-labels.yaml   # Namespace-level Pod Security Standards
│   │   └── gatekeeper-policies.yaml  # OPA Gatekeeper constraints
│   └── namespaces/
│       ├── production.yaml
│       ├── staging.yaml
│       └── monitoring.yaml
│
├── scripts/
│   ├── trivy-scan.sh              # Scan image + fail on HIGH/CRITICAL
│   ├── rbac-audit.sh              # Check for overprivileged service accounts
│   └── network-policy-test.sh    # Verify network policy enforcement
│
├── .github/
│   └── workflows/
│       ├── security-scan.yml      # Trivy + Kubesec + Checkov on every PR
│       └── deploy.yml             # Deploy only if scans pass
│
├── monitoring/
│   ├── prometheus/                # Security-focused alerting rules
│   └── grafana/                   # Security dashboard JSON
│
└── terraform/
    └── eks-cluster/               # Hardened EKS cluster with IRSA
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
Internet → Ingress Controller → [Service] → Pod  ✅ (via allow-ingress.yaml)
Pod → Pod (same namespace)                        ❌ (blocked by default)
Pod → Pod (cross-namespace)                       ❌ (blocked by default)
Pod → kube-dns (53/UDP)                           ✅ (via allow-dns.yaml)
Prometheus → Pod (metrics port)                   ✅ (via allow-monitoring.yaml)
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

**Manicharan Ravi** — Cloud Security Engineer  
📍 Mainz, Germany | ☁️ Kubernetes · Docker · DevSecOps · Helm · Terraform
