#!/usr/bin/env bash
# scripts/trivy-scan.sh
#
# Scan a container image with Trivy.
# Exits with code 1 if CRITICAL or HIGH vulnerabilities found.
#
# Usage:
#   bash scripts/trivy-scan.sh myrepo/myapp:v1.0.0
#   bash scripts/trivy-scan.sh myrepo/myapp:v1.0.0 --ignore-unfixed
#   SEVERITY=CRITICAL bash scripts/trivy-scan.sh myrepo/myapp:v1.0.0
#
# Author: Manicharan Ravi

set -euo pipefail

IMAGE="${1:-}"
SEVERITY="${SEVERITY:-CRITICAL,HIGH}"
IGNORE_UNFIXED="${2:-}"
OUTPUT_DIR="./reports"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image:tag> [--ignore-unfixed]"
  exit 1
fi

echo "🔍 Scanning image: $IMAGE"
echo "   Severity: $SEVERITY"
echo "   Ignore unfixed: ${IGNORE_UNFIXED:-no}"
echo ""

# Install trivy if not present
if ! command -v trivy &>/dev/null; then
  echo "Installing Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
fi

mkdir -p "$OUTPUT_DIR"
REPORT_FILE="$OUTPUT_DIR/trivy_$(echo "$IMAGE" | tr '/:' '__')_$(date +%Y%m%d_%H%M%S)"

# Run scan
TRIVY_ARGS=(
  image
  --severity "$SEVERITY"
  --format table
  --output "${REPORT_FILE}.txt"
  --exit-code 1
)

[[ "$IGNORE_UNFIXED" == "--ignore-unfixed" ]] && TRIVY_ARGS+=(--ignore-unfixed)

# Also generate JSON for processing
trivy image \
  --severity "$SEVERITY" \
  --format json \
  --output "${REPORT_FILE}.json" \
  "$IMAGE" || true

# Table output (with exit code)
if trivy "${TRIVY_ARGS[@]}" "$IMAGE"; then
  echo ""
  echo "✅ Trivy scan PASSED — no $SEVERITY vulnerabilities found."
  echo "   Report: ${REPORT_FILE}.txt"
  exit 0
else
  echo ""
  echo "❌ Trivy scan FAILED — $SEVERITY vulnerabilities found."
  echo "   Report: ${REPORT_FILE}.txt"
  echo ""
  echo "Summary of findings:"
  cat "${REPORT_FILE}.txt" | grep -E "^(Total:|CRITICAL|HIGH)" | head -20 || true
  exit 1
fi
