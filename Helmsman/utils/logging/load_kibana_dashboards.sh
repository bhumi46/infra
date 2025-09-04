#!/bin/sh

# Improved error handling - don't exit immediately on error
set -o pipefail

# Check required input
if [ $# -lt 1 ]; then
  echo "Usage: ./load_kibana_dashboards.sh <dashboards folder> [kubeconfig file]"
  exit 1
fi

# Optional kubeconfig
if [ $# -ge 2 ]; then
  export KUBECONFIG=$2
fi

# Fetch default values from config map with error handling
KIBANA_URL=""
INSTALL_NAME=""

if ! KIBANA_URL=$(kubectl get cm global -o jsonpath={.data.mosip-kibana-host} 2>/dev/null); then
  echo "Warning: Could not fetch kibana host from global configmap"
  exit 1
fi

if ! INSTALL_NAME=$(kubectl get cm global -o jsonpath={.data.installation-name} 2>/dev/null); then
  echo "Warning: Could not fetch installation name from global configmap"
  exit 1
fi

# Validate required values
if [ -z "$KIBANA_URL" ] || [ -z "$INSTALL_NAME" ]; then
  echo "Error: Missing required configuration (KIBANA_URL: $KIBANA_URL, INSTALL_NAME: $INSTALL_NAME)"
  exit 1
fi

echo "Using Kibana URL: https://$KIBANA_URL"
echo "Using Installation Name: $INSTALL_NAME"

# Optional: override using environment variables if provided
KIBANA_URL="${KIBANA_HOST_OVERRIDE:-$KIBANA_URL}"
INSTALL_NAME="${INSTALL_NAME_OVERRIDE:-$INSTALL_NAME}"

# Temporary file
TEMP_OBJ_FILE="/tmp/temp_kib_obj.ndjson"

# Process each .ndjson file
for file in ${1%/}/*.ndjson; do
  if [ ! -f "$file" ]; then
    echo "No .ndjson files found in $1"
    exit 1
  fi
  
  cp "$file" "$TEMP_OBJ_FILE"
  sed -i.bak "s/___DB_PREFIX_INDEX___/$INSTALL_NAME/g" "$TEMP_OBJ_FILE"

  echo
  echo "Loading: $file"
  
  # Test connectivity first
  if ! curl -f -s --connect-timeout 10 --max-time 30 "https://${KIBANA_URL%/}/api/status" > /dev/null; then
    echo "Error: Cannot connect to Kibana at https://${KIBANA_URL%/}"
    echo "Please check if Kibana is running and accessible"
    rm -f "$TEMP_OBJ_FILE" "$TEMP_OBJ_FILE.bak"
    exit 1
  fi
  
  # Load the dashboard
  if curl -f --connect-timeout 10 --max-time 60 -XPOST "https://${KIBANA_URL%/}/api/saved_objects/_import" \
    -H "kbn-xsrf: true" --form file=@"$TEMP_OBJ_FILE"; then
    echo "Successfully loaded: $file"
  else
    echo "Failed to load: $file"
    rm -f "$TEMP_OBJ_FILE" "$TEMP_OBJ_FILE.bak"
    exit 1
  fi

  rm -f "$TEMP_OBJ_FILE" "$TEMP_OBJ_FILE.bak"
done

echo "All dashboards loaded successfully"
