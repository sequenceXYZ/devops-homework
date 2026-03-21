#!/usr/bin/env bash

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and print each command before executing it (-x)
set -euo pipefail
set -x

# Get the absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine the project root directory (parent of the script directory)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Application name used in Kubernetes resources
APP_NAME="${APP_NAME:-datetime-app}"

# Docker image name
IMAGE_NAME="${IMAGE_NAME:-datetime-app}"

# Docker image tag
IMAGE_TAG="${IMAGE_TAG:-v1}"

# Full Docker image reference in name:tag format
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Path to the Kubernetes manifests directory
K8S_DIR="${K8S_DIR:-${PROJECT_ROOT}/k8s}"

# Host header expected by the Ingress
INGRESS_HOST="${INGRESS_HOST:-datetime.local}"

# Timeout for waiting until the Kubernetes deployment rollout completes
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"

# Print an informational message
log() {
  echo
  echo "[INFO] $1"
}

# Print an error message
error() {
  echo
  echo "[ERROR] $1"
}

# Check whether a required command exists in PATH
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Verify that all required tools are installed
require_tools() {
  local missing=0

  for cmd in docker kubectl minikube curl sg; do
    if ! command_exists "$cmd"; then
      error "Required command not found: $cmd"
      missing=1
    fi
  done

  # Exit if at least one required tool is missing
  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi
}

# Ensure Minikube is running and accessible
check_minikube() {
  log "Checking Minikube status..."

  # Check Minikube status as the docker group user
  if ! sg docker -c "minikube status" >/dev/null 2>&1; then
    error "Minikube is not running or is not accessible."
    error "Run ./scripts/setup-minikube.sh first."
    exit 1
  fi

  # Verify kubectl can communicate with the cluster
  kubectl get nodes >/dev/null 2>&1 || {
    error "kubectl cannot access the cluster."
    exit 1
  }
}

# Build the Docker image from the project root directory
build_image() {
  log "Building Docker image: ${FULL_IMAGE}"
  cd "${PROJECT_ROOT}"
  sg docker -c "docker build -t ${FULL_IMAGE} ."
}

# Load the built Docker image into the Minikube image cache
load_image() {
  log "Loading image into Minikube: ${FULL_IMAGE}"
  sg docker -c "minikube image load ${FULL_IMAGE}"
}

# Apply Kubernetes manifest files for deployment, service, ingress, and optionally HPA
deploy_manifests() {
  log "Applying Kubernetes manifests from ${K8S_DIR}"
  kubectl apply -f "${K8S_DIR}/deployment.yaml"
  kubectl apply -f "${K8S_DIR}/service.yaml"
  kubectl apply -f "${K8S_DIR}/ingress.yaml"

  # Apply HPA only if the manifest file exists
  if [[ -f "${K8S_DIR}/hpa.yaml" ]]; then
    log "Applying HPA manifest"
    kubectl apply -f "${K8S_DIR}/hpa.yaml"
  else
    log "No hpa.yaml found, skipping HPA deployment"
  fi
}

# Wait until the Kubernetes deployment rollout is completed
wait_for_rollout() {
  log "Waiting for deployment rollout..."
  kubectl rollout status deployment/"${APP_NAME}" --timeout="${ROLLOUT_TIMEOUT}"
}

# Wait until the service has ready endpoints exposed through EndpointSlice
wait_for_endpoints() {
  log "Waiting for service endpoints via EndpointSlice..."

  # Retry for up to 30 attempts with a short delay
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

  # Print debug information and fail if endpoints never become ready
  error "Service endpoints did not become ready in time."
  kubectl get endpointslices -l "kubernetes.io/service-name=${APP_NAME}-service" || true
  exit 1
}

# Display the current state of the deployment, service, ingress, HPA, and Minikube
show_status() {
  log "Pods:"
  kubectl get pods

  log "Service:"
  kubectl get svc

  log "Ingress:"
  kubectl get ingress

  # Show HPA status only if it exists
  if kubectl get hpa "${APP_NAME}-hpa" >/dev/null 2>&1; then
    log "HPA:"
    kubectl get hpa
  fi

  log "Minikube status:"
  sg docker -c "minikube status" || true
}

# Test the deployed application through the Ingress using the Minikube IP
test_app() {
  local mkip
  local response

  # Get the Minikube cluster IP
  mkip="$(sg docker -c "minikube ip")"

  log "Testing application through Ingress..."
  echo "Request:"
  echo "curl -H \"Host: ${INGRESS_HOST}\" http://${mkip}"
  echo

  # Send an HTTP request with the required Host header
  response="$(curl -fsS -H "Host: ${INGRESS_HOST}" "http://${mkip}")" || {
    error "Application test failed."
    exit 1
  }

  # Print application response
  echo "${response}"
}

# Main execution flow
main() {
  require_tools
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

# Run the main function and pass all script arguments to it
main "$@"
