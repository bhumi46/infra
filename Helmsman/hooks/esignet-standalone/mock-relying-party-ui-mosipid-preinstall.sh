#!/bin/bash
# =============================================================================
# eSignet 1.7.1 - Mock Relying Party UI MOSIP-ID Instance Pre-install (Generic)
# =============================================================================
# Ensures target namespace exists before UI deployment.
# Called via DSF with: env ESIGNET_NS=${MOSIPID1_NS} $WORKDIR/hooks/.../this.sh
#
# Required env vars:
#   ESIGNET_NS - target namespace (e.g. esignet-mosipid1)
# =============================================================================
set -euo pipefail

ESIGNET_NS="${ESIGNET_NS:?ERROR: ESIGNET_NS must be set}"

echo "================================================"
echo "eSignet 1.7.1 - Mock Relying Party UI Pre-install ($ESIGNET_NS)"
echo "================================================"

kubectl create namespace "$ESIGNET_NS" --dry-run=client -o yaml | kubectl apply -f -

if kubectl -n "$ESIGNET_NS" get svc mock-relying-party-service &>/dev/null; then
  echo "Mock relying party service found in $ESIGNET_NS."
else
  echo "WARNING: Mock relying party service not found in $ESIGNET_NS. UI depends on the service."
fi

echo "Mock relying party UI pre-install completed for $ESIGNET_NS."
