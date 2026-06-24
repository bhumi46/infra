#!/bin/bash
# =============================================================================
# eSignet 1.7.1 - PMS Partner MOSIP-ID Instance Pre-install (Generic)
# =============================================================================
# Creates the Istio Gateway for pms-partner in the target namespace.
# Called via DSF with:
#   env ESIGNET_NS=${MOSIPID1_NS} MOSIPID_SUFFIX=mosipid1 $WORKDIR/hooks/.../this.sh
#
# Required env vars:
#   ESIGNET_NS     - target namespace (e.g. esignet-mosipid1)
#   MOSIPID_SUFFIX - resource name suffix (e.g. mosipid1)
# Also requires: domain_name (set by workflow as env var)
# =============================================================================
set -euo pipefail

ESIGNET_NS="${ESIGNET_NS:?ERROR: ESIGNET_NS must be set}"
MOSIPID_SUFFIX="${MOSIPID_SUFFIX:?ERROR: MOSIPID_SUFFIX must be set}"

echo "================================================"
echo "eSignet 1.7.1 - PMS Partner Pre-install ($ESIGNET_NS)"
echo "================================================"

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: pms-partner-${MOSIPID_SUFFIX}-gateway
  namespace: ${ESIGNET_NS}
  labels:
    app.kubernetes.io/instance: pms-partner-${MOSIPID_SUFFIX}
    app.kubernetes.io/name: pms-partner
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - pms-${MOSIPID_SUFFIX}.${domain_name}
      port:
        name: https
        number: 443
        protocol: HTTPS
      tls:
        credentialName: pms-partner-${MOSIPID_SUFFIX}-tls
        mode: SIMPLE
    - hosts:
        - pms-${MOSIPID_SUFFIX}.${domain_name}
      port:
        name: http
        number: 80
        protocol: HTTP
EOF

echo "pms-partner-${MOSIPID_SUFFIX}-gateway created/updated in $ESIGNET_NS."
