#!/usr/bin/env bash

# Exit immediately if a command fails (-e),
# treat unset variables as errors (-u),
# and print each command before executing it (-x)
# This ensures strict error handling and easier debugging
set -euo pipefail
set -x

# Get the absolute path to the directory where this script is located
# This allows the script to be run from any location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine the project root directory (parent of the script directory)
# Used as a base path for Docker build and Kubernetes manifests
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Application name used in Kubernetes resources (Deployment, Service, HPA)
# Can be overridden via environment variable
APP_NAME="${APP_NAME:-datetime-app}"

# Docker image name (repository name)
IMAGE_NAME="${IMAGE_NAME:-datetime-app}"

# Docker image tag (version)
IMAGE_TAG="${IMAGE_TAG:-v1}"

# Full Docker image reference in name:tag format
# Example: datetime-app:v1
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Path to the Kubernetes manifests directory
# Defaults to <project_root>/k8s
K8S_DIR="${K8S_DIR:-${PROJECT_ROOT}/k8s}"

# Host header expected by the Ingress resource
# Used for testing via curl
INGRESS_HOST="${INGRESS_HOST:-datetime.local}"

# Timeout for waiting until the Kubernetes deployment rollout completes
# Prevents infinite waiting if something goes wrong
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"

# Print an informational message with consistent formatting
log() {
  echo
  echo "[INFO] $1"
}

# Print an error message with consistent formatting
error() {
  echo
  echo "[ERROR] $1"
}

# Check whether a required command exists in PATH
# Returns 0 if found, otherwise non-zero
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Verify that all required CLI tools are installed before execution
# Required tools: Docker, kubectl, Minikube, curl, sg (for docker group execution)
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
# Also validates kubectl connectivity to the cluster
check_minikube() {
  log "Checking Minikube status..."

  # Run Minikube command under docker group (important for permissions)
  if ! sg docker -c "minikube status" >/dev/null 2>&1; then
    error "Minikube is not running or is not accessible."
    error "Run ./scripts/setup-minikube.sh first."
    exit 1
  fi

  # Verify kubectl can communicate with the cluster API
  kubectl get nodes >/dev/null 2>&1 || {
    error "kubectl cannot access the cluster."
    exit 1
  }
}

# Build the Docker image from the project root directory
# Uses Dockerfile located in the root of the project
build_image() {
  log "Building Docker image: ${FULL_IMAGE}"
  cd "${PROJECT_ROOT}"
  sg docker -c "docker build -t ${FULL_IMAGE} ."
}

# Load the built Docker image into the Minikube internal registry/cache
# Required when using Minikube instead of a remote registry
load_image() {
  log "Loading image into Minikube: ${FULL_IMAGE}"
  sg docker -c "minikube image load ${FULL_IMAGE}"
}

# Apply Kubernetes manifest files:
# - Deployment (pods)
# - Service (network access)
# - Ingress (external access)
# - HPA (optional autoscaling)
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

# Wait until the Kubernetes Deployment rollout is completed
# Ensures pods are successfully created and ready
wait_for_rollout() {
  log "Waiting for deployment rollout..."
  kubectl rollout status deployment/"${APP_NAME}" --timeout="${ROLLOUT_TIMEOUT}"
}

# Wait until the Service has active endpoints (pods attached)
# Uses EndpointSlice API (modern Kubernetes approach)
wait_for_endpoints() {
  log "Waiting for service endpoints via EndpointSlice..."

  # Retry loop (max ~60 seconds)
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

  # If no endpoints found, print debug info and fail
  error "Service endpoints did not become ready in time."
  kubectl get endpointslices -l "kubernetes.io/service-name=${APP_NAME}-service" || true
  exit 1
}

# Display current cluster state for debugging/visibility:
# - Pods
# - Service
# - Ingress
# - HPA (if exists)
# - Minikube status
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

# Test the deployed application through Ingress
# Uses curl with Host header to simulate DNS routing
test_app() {
  local mkip
  local response

  # Get Minikube cluster IP address
  mkip="$(sg docker -c "minikube ip")"

  log "Testing application through Ingress..."
  echo "Request:"
  echo "curl -H \"Host: ${INGRESS_HOST}\" http://${mkip}"
  echo

  # Perform HTTP request and fail if it does not succeed
  response="$(curl -fsS -H "Host: ${INGRESS_HOST}" "http://${mkip}")" || {
    error "Application test failed."
    exit 1
  }

  # Output application response
  echo "${response}"
}

# Main execution flow of the script
# Defines the full CI/CD-like pipeline locally
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

# Entry point of the script
# Passes all CLI arguments to main()
main "$@"
