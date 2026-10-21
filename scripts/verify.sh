#!/usr/bin/env bash
# Smoke tests: each control should block what it claims to block.
set -u
pass=0; fail=0
check() { # check "<description>" <expected: reject|allow> <command...>
  local desc=$1 expect=$2; shift 2
  if "$@" >/dev/null 2>&1; then got=allow; else got=reject; fi
  if [ "$got" = "$expect" ]; then echo "PASS  $desc"; pass=$((pass+1)); else echo "FAIL  $desc (expected $expect, got $got)"; fail=$((fail+1)); fi
}

NS=production

check "privileged pod is rejected by PSA" reject \
  kubectl run bad-priv -n $NS --image=busybox:1.36 --dry-run=server \
  --overrides='{"spec":{"containers":[{"name":"bad-priv","image":"busybox:1.36","securityContext":{"privileged":true}}]}}'

check "root user pod is rejected by PSA" reject \
  kubectl run bad-root -n $NS --image=busybox:1.36 --dry-run=server \
  --overrides='{"spec":{"securityContext":{"runAsUser":0},"containers":[{"name":"bad-root","image":"busybox:1.36"}]}}'

check "hostPath pod is rejected" reject \
  kubectl apply -n $NS --dry-run=server -f examples/insecure-pod.yaml

check "default-deny NetworkPolicy exists" allow \
  kubectl get networkpolicy default-deny-all -n $NS

echo; echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
