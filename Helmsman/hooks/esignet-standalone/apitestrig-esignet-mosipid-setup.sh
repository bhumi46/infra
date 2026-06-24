#!/bin/bash
# =============================================================================
# eSignet 1.7.1 - eSignet MOSIP-ID API Testrig Pre-install (Generic)
# =============================================================================
# Prepares the target namespace for an esignet apitestrig release.
# Called via DSF with: env ESIGNET_NS=${MOSIPID1_NS} $WORKDIR/hooks/.../this.sh
#
# Required env vars:
#   ESIGNET_NS - target namespace (e.g. esignet-mosipid1)
# =============================================================================
set -euo pipefail

NS="${ESIGNET_NS:?ERROR: ESIGNET_NS must be set}"
COPY_UTIL="$WORKDIR/utils/copy-cm-and-secrets/copy_cm_func.sh"

echo "================================================"
echo "eSignet 1.7.1 - eSignet API Testrig Pre-install ($NS)"
echo "================================================"

echo "Deleting stale testrig configmaps in $NS"
kubectl -n "$NS" delete --ignore-not-found=true configmap s3
kubectl -n "$NS" delete --ignore-not-found=true configmap db
kubectl -n "$NS" delete --ignore-not-found=true configmap apitestrig

echo "Copying postgres-postgresql secret to $NS"
$COPY_UTIL secret postgres-postgresql postgres "$NS"

echo "eSignet API Testrig pre-install setup completed for $NS."
