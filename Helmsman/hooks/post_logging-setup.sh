#!/bin/bash

if [ $# -ge 1 ] ; then
  export KUBECONFIG=$1
fi

function post_logging_setup() {
  echo "Waiting for services to be ready..."
  sleep 30  # increased wait time for services to initialize
  
  # Wait for Elasticsearch to be ready
  echo "Waiting for Elasticsearch to be ready..."
  timeout 300s bash -c 'until kubectl get pods -n cattle-logging-system -l app=elasticsearch-master --field-selector=status.phase=Running | grep -q Running; do sleep 10; done'
  
  # Additional wait for Elasticsearch internal readiness
  sleep 20
  
  echo "Adding Index Lifecycle Policy and Index Template to Elasticsearch"
  kubectl exec -it elasticsearch-master-0 -n cattle-logging-system -- curl -XPUT "http://elasticsearch-master:9200/_ilm/policy/3_days_delete_policy" -H 'Content-Type: application/json' -d'
  {
    "policy": {
      "phases": {
        "delete": {
          "min_age": "3d",
          "actions": {
            "delete": {}
          }
        }
      }
    }
  }'
  kubectl exec -it elasticsearch-master-0 -n cattle-logging-system -- curl -XPUT "http://elasticsearch-master:9200/_index_template/logstash_template" -H 'Content-Type: application/json' -d'
  {
    "index_patterns": ["logstash-*"],
    "template": {
      "settings": {
        "index": {
          "lifecycle": {
            "name": "3_days_delete_policy"
          }
        }
      },
      "aliases": {},
      "mappings": {}
    }
  }'

  echo "Configure Rancher FluentD"
  kubectl apply -f $WORKDIR/utils/logging/clusteroutput-elasticsearch.yaml
  kubectl apply -f $WORKDIR/utils/logging/clusterflow-elasticsearch.yaml

  echo "Load Dashboards"
  
  # Check if dashboard loading should be skipped
  if [ "${SKIP_KIBANA_DASHBOARDS:-false}" = "true" ]; then
    echo "Skipping Kibana dashboard loading (SKIP_KIBANA_DASHBOARDS=true)"
    return 0
  fi
  
  # Wait for Kibana to be ready before loading dashboards
  echo "Waiting for Kibana service to be ready..."
  timeout 300s bash -c 'until kubectl get pods -n cattle-logging-system -l app=kibana --field-selector=status.phase=Running | grep -q Running; do sleep 10; done' || true
  
  # Additional wait for Kibana to fully initialize
  sleep 60
  
  # Try to load dashboards with retries and better error handling
  for attempt in 1 2 3; do
    echo "Attempt $attempt: Loading Kibana dashboards..."
    if $WORKDIR/utils/logging/load_kibana_dashboards.sh $WORKDIR/utils/logging/dashboards $KUBECONFIG; then
      echo "Dashboards loaded successfully"
      break
    else
      echo "Dashboard loading failed on attempt $attempt"
      if [ $attempt -eq 3 ]; then
        echo "WARNING: Dashboard loading failed after 3 attempts. Continuing anyway..."
        echo "You may need to load dashboards manually later."
        echo "To skip dashboard loading in future, set SKIP_KIBANA_DASHBOARDS=true"
        # Don't exit with error, just continue
        break
      else
        echo "Retrying in 30 seconds..."
        sleep 30
      fi
    fi
  done
  return 0
}

# set commands for error handling.
set -e
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errtrace  # trace ERR through 'time command' and other functions
set -o pipefail  # trace ERR through pipes
post_logging_setup   # calling function  
