# Conftest policies for rendered Kubernetes manifests (run in CI against `helm template` output).
# Mirrors the Gatekeeper constraints in manifests/pod-security/ so violations are caught before deploy.
package main

import rego.v1

workloads := {"Deployment", "StatefulSet", "DaemonSet"}

containers contains c if {
	workloads[input.kind]
	some c in input.spec.template.spec.containers
}

deny contains msg if {
	some c in containers
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("%s/%s: container '%s' must set allowPrivilegeEscalation: false", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	c.securityContext.privileged == true
	msg := sprintf("%s/%s: container '%s' must not be privileged", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not c.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("%s/%s: container '%s' must use a read-only root filesystem", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not "ALL" in c.securityContext.capabilities.drop
	msg := sprintf("%s/%s: container '%s' must drop ALL capabilities", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("%s/%s: container '%s' must set a memory limit", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("%s/%s: container '%s' must not use the :latest tag", [input.kind, input.metadata.name, c.name])
}

deny contains msg if {
	workloads[input.kind]
	not input.spec.template.spec.securityContext.runAsNonRoot == true
	msg := sprintf("%s/%s: pod must set runAsNonRoot: true", [input.kind, input.metadata.name])
}

deny contains msg if {
	workloads[input.kind]
	input.spec.template.spec.hostNetwork == true
	msg := sprintf("%s/%s: hostNetwork is not allowed", [input.kind, input.metadata.name])
}
