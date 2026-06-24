#!/bin/bash
# =============================================================================
# eSignet 1.7.1 - eSignet MOSIP-ID Instance Pre-install (Generic)
# =============================================================================
# Generic pre-install for any mosip-identity-plugin eSignet instance.
# Called via DSF with instance-specific env vars injected through `env`:
#
#   env ESIGNET_NS=${MOSIPID1_NS} \
#       MOSIPID_DOMAIN=${MOSIPID1_DOMAIN} \
#       MOSIPID_SUFFIX=mosipid1 \
#       MOSIPID_CAPTCHA_SITE_KEY=${ESIGNET_MOSIPID1_CAPTCHA_SITE_KEY} \
#       MOSIPID_CAPTCHA_SECRET_KEY=${ESIGNET_MOSIPID1_CAPTCHA_SECRET_KEY} \
#       MOSIPID_POSTGRES_PASSWORD=${MOSIPID1_POSTGRES_PASSWORD} \
#       MOSIPID_KEYCLOAK_ADMIN_PASSWORD=${MOSIPID1_KEYCLOAK_ADMIN_PASSWORD} \
#       $WORKDIR/hooks/esignet-standalone/esignet-mosipid-preinstall.sh
#
# Required env vars (all injected by the DSF hook command above):
#   ESIGNET_NS                    - target namespace (e.g. esignet-mosipid1)
#   MOSIPID_DOMAIN                - connecting MOSIP environment domain (e.g. cre.example.net)
#   MOSIPID_SUFFIX                - suffix used in resource names (e.g. mosipid1)
#   MOSIPID_CAPTCHA_SITE_KEY      - reCAPTCHA site key for this instance
#   MOSIPID_CAPTCHA_SECRET_KEY    - reCAPTCHA secret key for this instance
#   MOSIPID_POSTGRES_PASSWORD     - postgres superuser password for remote env
#   MOSIPID_KEYCLOAK_ADMIN_PASSWORD - Keycloak admin password for remote env
# Also requires: domain_name (set by workflow as env var)
# =============================================================================
set -euo pipefail

ESIGNET_NS="${ESIGNET_NS:?ERROR: ESIGNET_NS must be set}"
MOSIPID_DOMAIN="${MOSIPID_DOMAIN:?ERROR: MOSIPID_DOMAIN must be set}"
MOSIPID_SUFFIX="${MOSIPID_SUFFIX:?ERROR: MOSIPID_SUFFIX must be set}"
CAPTCHA_SITE_KEY="${MOSIPID_CAPTCHA_SITE_KEY:?ERROR: MOSIPID_CAPTCHA_SITE_KEY must be set}"
CAPTCHA_SECRET_KEY="${MOSIPID_CAPTCHA_SECRET_KEY:?ERROR: MOSIPID_CAPTCHA_SECRET_KEY must be set}"
POSTGRES_PASS="${MOSIPID_POSTGRES_PASSWORD:?ERROR: MOSIPID_POSTGRES_PASSWORD must be set}"
KC_ADMIN_PASS="${MOSIPID_KEYCLOAK_ADMIN_PASSWORD:?ERROR: MOSIPID_KEYCLOAK_ADMIN_PASSWORD must be set}"

CAPTCHA_NS="captcha"
COPY_UTIL="$WORKDIR/utils/copy-cm-and-secrets/copy_cm_func.sh"
UPPER_SUFFIX="${MOSIPID_SUFFIX^^}"  # mosipid1 → MOSIPID1

echo "================================================"
echo "eSignet 1.7.1 - eSignet ${MOSIPID_SUFFIX} Pre-install"
echo "  ESIGNET_NS    = $ESIGNET_NS"
echo "  MOSIPID_DOMAIN = $MOSIPID_DOMAIN"
echo "  MOSIPID_SUFFIX = $MOSIPID_SUFFIX"
echo "================================================"

# --- Step 1: Base pre-install (namespace, postgres/redis configmaps+secrets) ---
"$WORKDIR/hooks/esignet-standalone/esignet-preinstall.sh"

# --- Step 2: Namespace-specific esignet-global configmap ---
echo "Creating esignet-global configmap in $ESIGNET_NS"
kubectl -n "$ESIGNET_NS" create configmap esignet-global \
  --from-literal=installation-domain="${domain_name}" \
  --from-literal=mosip-api-host="api.${domain_name}" \
  --from-literal=mosip-api-internal-host="api-internal.${domain_name}" \
  --from-literal=mosip-esignet-host="esignet-${MOSIPID_SUFFIX}.${domain_name}" \
  --from-literal=mosip-iam-external-host="iam.${domain_name}" \
  --from-literal=mosip-kafka-host="kafka.${domain_name}" \
  --from-literal=mosip-postgres-host="postgres.${domain_name}" \
  --from-literal=mosip-signup-host="signup-${MOSIPID_SUFFIX}.${domain_name}" \
  --from-literal=mosip-smtp-host="smtp.${domain_name}" \
  --from-literal=mosip-version="develop" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Step 3: Patch postgres-config with instance-specific DB values ---
echo "Patching postgres-config with ${MOSIPID_SUFFIX}-specific DB values"
kubectl -n "$ESIGNET_NS" patch configmap postgres-config --type merge \
  -p "{\"data\":{\"database-name\":\"mosip_esignet_${MOSIPID_SUFFIX}\",\"database-username\":\"esignetuser_${MOSIPID_SUFFIX}\"}}"

# --- Step 4: Create MISP onboarder key placeholder ---
if ! kubectl -n "$ESIGNET_NS" get secret esignet-misp-onboarder-key &>/dev/null; then
  kubectl -n "$ESIGNET_NS" create secret generic esignet-misp-onboarder-key \
    --from-literal=mosip-esignet-misp-key=""
  echo "esignet-misp-onboarder-key placeholder created in $ESIGNET_NS"
fi

# --- Step 5: Captcha secret ---
echo "Creating esignet-captcha-${MOSIPID_SUFFIX} secret in $CAPTCHA_NS"
kubectl -n "$CAPTCHA_NS" create secret generic "esignet-captcha-${MOSIPID_SUFFIX}" \
  --from-literal=esignet-captcha-site-key="$CAPTCHA_SITE_KEY" \
  --from-literal=esignet-captcha-secret-key="$CAPTCHA_SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Copying esignet-captcha-${MOSIPID_SUFFIX} from $CAPTCHA_NS to $ESIGNET_NS"
$COPY_UTIL secret "esignet-captcha-${MOSIPID_SUFFIX}" "$CAPTCHA_NS" "$ESIGNET_NS"

CAPTCHA_ENV_VAR="MOSIP_CAPTCHA_GOOGLERECAPTCHAV2_SECRET_ESIGNET${UPPER_SUFFIX}"
echo "Patching captcha deployment with $CAPTCHA_ENV_VAR"
ENV_VAR_EXISTS=$(kubectl -n "$CAPTCHA_NS" get deployment captcha \
  -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name=='${CAPTCHA_ENV_VAR}')].name}" 2>/dev/null || echo "")
if [[ -z "$ENV_VAR_EXISTS" ]]; then
  kubectl patch deployment -n "$CAPTCHA_NS" captcha --type='json' \
    -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/env/-\", \"value\": {\"name\": \"${CAPTCHA_ENV_VAR}\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"esignet-captcha-${MOSIPID_SUFFIX}\", \"key\": \"esignet-captcha-secret-key\"}}}}]"
else
  echo "$CAPTCHA_ENV_VAR already exists in captcha deployment."
fi

# --- Step 6: Remote postgres password secret ---
echo "Creating postgres-postgresql-${MOSIPID_SUFFIX} secret in $ESIGNET_NS"
kubectl -n "$ESIGNET_NS" create secret generic "postgres-postgresql-${MOSIPID_SUFFIX}" \
  --from-literal=postgres-password="${POSTGRES_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Step 7: Remote Keycloak host configmap ---
echo "Creating keycloak-host-${MOSIPID_SUFFIX} configmap in $ESIGNET_NS"
kubectl -n "$ESIGNET_NS" create configmap "keycloak-host-${MOSIPID_SUFFIX}" \
  --from-literal=keycloak-external-host="iam.${MOSIPID_DOMAIN}" \
  --from-literal=keycloak-external-url="https://iam.${MOSIPID_DOMAIN}" \
  --from-literal=keycloak-internal-host="keycloak.keycloak" \
  --from-literal=keycloak-internal-service-url="http://keycloak.keycloak/auth/" \
  --from-literal=keycloak-internal-url="http://keycloak.keycloak" \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Step 8: Fetch all confidential clients from remote Keycloak ---
KC_HOST="iam.${MOSIPID_DOMAIN}"
REALM="mosip"

echo "Fetching admin token from $KC_HOST"
TOKEN_RESPONSE=$(curl -sf -X POST \
  "https://${KC_HOST}/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=${KC_ADMIN_PASS}")
ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "❌ Failed to get admin token from $KC_HOST" >&2; exit 1
fi
echo "✓ Admin token obtained"

echo "Fetching all clients from realm $REALM on $KC_HOST"
CLIENTS=$(curl -sf \
  "https://${KC_HOST}/auth/admin/realms/${REALM}/clients?max=500" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

SECRET_ARGS=()
while IFS= read -r client_json; do
  client_id=$(echo "$client_json" | jq -r '.clientId')
  uuid=$(echo "$client_json"      | jq -r '.id')
  auth_type=$(echo "$client_json" | jq -r '.clientAuthenticatorType')
  is_public=$(echo "$client_json" | jq -r '.publicClient')
  [[ "$auth_type" != "client-secret" || "$is_public" == "true" ]] && continue
  secret_val=$(curl -sf \
    "https://${KC_HOST}/auth/admin/realms/${REALM}/clients/${uuid}/client-secret" \
    -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.value // empty')
  [[ -z "$secret_val" || "$secret_val" == "null" ]] && continue
  key=$(echo "$client_id" | tr '-' '_')_secret
  SECRET_ARGS+=("--from-literal=${key}=${secret_val}")
  echo "  ✓ $client_id"
done < <(echo "$CLIENTS" | jq -c '.[]')

if [[ ${#SECRET_ARGS[@]} -eq 0 ]]; then
  echo "❌ No client secrets fetched from ${MOSIPID_SUFFIX} Keycloak" >&2; exit 1
fi
echo "Creating keycloak-client-secrets-${MOSIPID_SUFFIX} in $ESIGNET_NS (${#SECRET_ARGS[@]} clients)"
kubectl -n "$ESIGNET_NS" create secret generic "keycloak-client-secrets-${MOSIPID_SUFFIX}" \
  "${SECRET_ARGS[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ keycloak-client-secrets-${MOSIPID_SUFFIX} created"

echo "eSignet ${MOSIPID_SUFFIX} pre-install completed."
