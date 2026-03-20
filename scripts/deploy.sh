#!/usr/bin/env bash

set -euo pipefail

APP_NAME="${APP_NAME:-datetime-app}"
IMAGE_NAME="${IMAGE_NAME:-datetime-app}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
K8S_DIR="${K8S_DIR:-k8s}"
INGRESS_HOST="${INGRESS_HOST:-datetime.local}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"

log() {
  echo
  echo "[INFO] $1"
}

error() {
  echo
  echo "[ERROR] $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_tools() {
  local missing=0

  for cmd in docker kubectl minikube curl sg; do
    if ! command_exists "$cmd"; then
      error "Required command not found: $cmd"
      missing=1
    fi
  done

  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

ensure_docker_access() {
  if docker ps >/dev/null 2>&1; then
    return 0
  fi

  log "Current shell does not have Docker access. Re-running deploy.sh in docker group shell..."
  exec sg docker -c "$0"
}

check_minikube() {
  log "Checking Minikube status..."

  if ! minikube status >/dev/null 2>&1; then
    error "Minikube is not running."
    error "Run ./scripts/setup-minikube.sh first."
    exit 1
  fi

  kubectl get nodes >/dev/null 2>&1 || {
    error "kubectl cannot access the cluster."
    exit 1
  }
}

build_image() {
  log "Building Docker image: ${FULL_IMAGE}"
  docker build -t "${FULL_IMAGE}" .
}

load_image() {
  log "Loading image into Minikube: ${FULL_IMAGE}"
  minikube image load "${FULL_IMAGE}"
}

deploy_manifests() {
  log "Applying Kubernetes manifests from ${K8S_DIR}/"
  kubectl apply -f "${K8S_DIR}/deployment.yaml"
  kubectl apply -f "${K8S_DIR}/service.yaml"
  kubectl apply -f "${K8S_DIR}/ingress.yaml"

  if [[ -f "${K8S_DIR}/hpa.yaml" ]]; then
    log "Applying HPA manifest"
    kubectl apply -f "${K8S_DIR}/hpa.yaml"
  else
    log "No hpa.yaml found, skipping HPA deployment"
  fi
}

wait_for_rollout() {
  log "Waiting for deployment rollout..."
  kubectl rollout status deployment/"${APP_NAME}" --timeout="${ROLLOUT_TIMEOUT}"
}

wait_for_endpoints() {
  log "Waiting for service endpoints via EndpointSlice..."

  for i in {1..30}; do
    if kubectl get endpointslices \
      -l "kubernetes.io/service-name=${APP_NAME}-service" \
      -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null | grep -q .; then
      log "Service endpoints are ready."
      sleep 5
      return 0
    fi
    sleep 2
  done

  error "Service endpoints did not become ready in time."
  kubectl get endpointslices -l "kubernetes.io/service-name=${APP_NAME}-service" || true
  exit 1
}

show_status() {
  log "Pods:"
  kubectl get pods

  log "Service:"
  kubectl get svc

  log "Ingress:"
  kubectl get ingress

  if kubectl get hpa "${APP_NAME}-hpa" >/dev/null 2>&1; then
    log "HPA:"
    kubectl get hpa
  fi
}

test_app() {
  local mkip
  local response

  mkip="$(minikube ip)"

  log "Testing application through Ingress..."
  echo "Request:"
  echo "curl -H \"Host: ${INGRESS_HOST}\" http://${mkip}"
  echo

  response="$(curl -fsS -H "Host: ${INGRESS_HOST}" "http://${mkip}")" || {
    error "Application test failed."
    exit 1
  }

  echo "${response}"
}

main() {
  require_tools
  ensure_docker_access
  check_minikube
  build_image
  load_image
  deploy_manifests
  wait_for_rollout
  wait_for_endpoints
  show_status
  test_app

  log "Deployment completed successfully."
}

main "$@"
