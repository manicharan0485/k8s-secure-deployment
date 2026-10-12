#!/usr/bin/env bash
# scripts/rbac-audit.sh
#
# Audits Kubernetes RBAC for overprivileged service accounts and bindings.
# Checks for:
#   - Service accounts with cluster-admin
#   - Wildcards (* verbs or * resources) in roles
#   - Default service account usage
#   - Automounted service account tokens
#
# Usage:
#   bash scripts/rbac-audit.sh
#   bash scripts/rbac-audit.sh --namespace production
#   bash scripts/rbac-audit.sh --output report.txt
#
# Author: Manicharan Ravi

set -euo pipefail

NAMESPACE="${NAMESPACE:-}"
OUTPUT=""
ISSUES=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace|-n) NAMESPACE="$2"; shift ;;
    --output|-o)    OUTPUT="$2"; shift ;;
    *) echo "Unknown: $1" ;;
  esac
  shift
done

NS_FLAG=""
[[ -n "$NAMESPACE" ]] && NS_FLAG="-n $NAMESPACE"

log()  { echo "[AUDIT] $*"; }
warn() { echo "[WARN]  ⚠️  $*"; ((ISSUES++)); }
ok()   { echo "[OK]    ✅ $*"; }
err()  { echo "[FAIL]  ❌ $*"; ((ISSUES++)); }

{
echo "=================================================="
echo " Kubernetes RBAC Security Audit"
echo " Date     : $(date)"
echo " Namespace: ${NAMESPACE:-all}"
echo "=================================================="
echo ""

# ── 1. Check for cluster-admin bindings ───────────────────────────────────
echo "=== Cluster-Admin Bindings ==="
CLUSTER_ADMIN=$(kubectl get clusterrolebindings -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
found = []
for b in data['items']:
  if b.get('roleRef', {}).get('name') == 'cluster-admin':
    subjects = b.get('subjects', [])
    for s in subjects:
      found.append(f\"{b['metadata']['name']} -> {s.get('kind','?')}/{s.get('name','?')}\")
print('\n'.join(found) if found else 'NONE')")

if [[ "$CLUSTER_ADMIN" == "NONE" ]]; then
  ok "No non-system cluster-admin bindings found"
else
  while IFS= read -r line; do
    # Skip system:masters and kube-system bindings
    if echo "$line" | grep -qE "system:|kubeadm|eks"; then
      log "System binding (expected): $line"
    else
      err "cluster-admin binding: $line"
    fi
  done <<< "$CLUSTER_ADMIN"
fi

echo ""

# ── 2. Check for wildcard permissions in Roles ───────────────────────────
echo "=== Wildcard Permissions in Roles ==="
kubectl get roles ${NS_FLAG} -o json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for role in data['items']:
  ns   = role['metadata']['namespace']
  name = role['metadata']['name']
  for rule in role.get('rules', []):
    verbs     = rule.get('verbs', [])
    resources = rule.get('resources', [])
    if '*' in verbs or '*' in resources:
      print(f'WILDCARD Role {ns}/{name}: verbs={verbs} resources={resources}')
" | while IFS= read -r line; do warn "$line"; done || ok "No wildcard roles in namespace(s)"

kubectl get clusterroles -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
skip = {'system:', 'kubeadm', 'calico', 'aws-', 'eks-', 'kube-', 'helm'}
for role in data['items']:
  name = role['metadata']['name']
  if any(name.startswith(s) for s in skip): continue
  for rule in role.get('rules', []):
    if '*' in rule.get('verbs', []) or '*' in rule.get('resources', []):
      print(f'WILDCARD ClusterRole {name}: {rule}')
" | while IFS= read -r line; do warn "$line"; done || ok "No unexpected wildcard cluster roles"

echo ""

# ── 3. Check default service account usage ───────────────────────────────
echo "=== Deployments Using Default Service Account ==="
kubectl get deployments ${NS_FLAG} -o json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for d in data['items']:
  ns   = d['metadata']['namespace']
  name = d['metadata']['name']
  sa   = d['spec']['template']['spec'].get('serviceAccountName', 'default')
  if sa == 'default':
    print(f'{ns}/{name} uses default service account')
" | while IFS= read -r line; do warn "$line — create a dedicated service account"; done || ok "No deployments using default SA"

echo ""

# ── 4. Check automounted service account tokens ──────────────────────────
echo "=== Automounted Service Account Tokens ==="
kubectl get pods ${NS_FLAG} -o json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for pod in data['items']:
  ns   = pod['metadata']['namespace']
  name = pod['metadata']['name']
  auto = pod['spec'].get('automountServiceAccountToken', True)
  if auto:
    print(f'{ns}/{name} has automountServiceAccountToken enabled')
" | while IFS= read -r line; do warn "$line — set automountServiceAccountToken: false if not needed"; done || ok "No pods with automounted tokens"

echo ""

# ── 5. Check for secrets-listing permissions ─────────────────────────────
echo "=== Roles with Secrets List/Get Permission ==="
kubectl get roles ${NS_FLAG} -o json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for role in data['items']:
  ns   = role['metadata']['namespace']
  name = role['metadata']['name']
  for rule in role.get('rules', []):
    if 'secrets' in rule.get('resources', []):
      if any(v in rule.get('verbs', []) for v in ['list', '*']):
        print(f'{ns}/{name} can LIST secrets (consider restricting to get only)')
" | while IFS= read -r line; do warn "$line"; done || ok "No roles with broad secrets access"

echo ""
echo "=================================================="
echo " AUDIT COMPLETE"
echo " Issues found: $ISSUES"
if [[ $ISSUES -eq 0 ]]; then
  echo " ✅ PASSED — No RBAC issues detected"
else
  echo " ⚠️  REVIEW REQUIRED — $ISSUES issue(s) found above"
fi
echo "=================================================="
} | tee "${OUTPUT:-/dev/stderr}"

exit $([[ $ISSUES -gt 5 ]] && echo 1 || echo 0)
