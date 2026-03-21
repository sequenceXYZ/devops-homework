#!/usr/bin/env bash

# Enable strict mode:
# -e  -> exit on error
# -u  -> treat unset variables as errors
# -o pipefail -> fail if any command in a pipeline fails
# -x  -> print commands (debugging)
set -euo pipefail
set -x

# Minikube resource configuration (can be overridden via environment variables)
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-2200}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-2}"

# kubectl version to install
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.31.0}"

# Timeout for waiting on apt/dpkg locks (in seconds)
APT_LOCK_TIMEOUT_SECONDS="${APT_LOCK_TIMEOUT_SECONDS:-300}"

# Disable interactive prompts for apt
export DEBIAN_FRONTEND=noninteractive

# Print informational message
log() {
  echo
  echo "[INFO] $1"
}

# Print error message
error() {
  echo
  echo "[ERROR] $1"
}

# Check if a command exists in PATH
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure sudo is available (required for installation steps)
ensure_sudo() {
  if ! command_exists sudo; then
    error "sudo is required but not installed."
    exit 1
  fi
}

# Wait for cloud-init to finish (important on fresh VM instances like EC2)
wait_for_cloud_init() {
  log "Waiting for cloud-init to finish..."
  if command_exists cloud-init; then
    sudo cloud-init status --wait
  fi
}

# Disable Ubuntu background apt services that can cause lock conflicts
disable_apt_background_services() {
  log "Disabling Ubuntu background apt services..."
  sudo systemctl stop apt-daily.service apt-daily.timer || true
  sudo systemctl stop apt-daily-upgrade.service apt-daily-upgrade.timer || true
  sudo systemctl stop unattended-upgrades.service || true

  sudo systemctl mask apt-daily.service apt-daily.timer || true
  sudo systemctl mask apt-daily-upgrade.service apt-daily-upgrade.timer || true
  sudo systemctl mask unattended-upgrades.service || true
}

# Wait until apt/dpkg locks are released before installing packages
wait_for_apt() {
  log "Waiting for apt/dpkg lock to be released..."

  local waited=0
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
     || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
     || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do

    # Timeout protection
    if [ "$waited" -ge "$APT_LOCK_TIMEOUT_SECONDS" ]; then
      error "Timeout waiting for apt/dpkg lock after ${APT_LOCK_TIMEOUT_SECONDS} seconds."
      sudo ps aux | grep -E 'apt|dpkg|unattended|cloud-init' || true
      exit 1
    fi

    sleep 5
    waited=$((waited + 5))
    log "apt lock still held, waited ${waited}s..."
  done

  log "apt/dpkg lock is free."
}

# Install base system packages required for the environment
install_base_packages() {
  wait_for_apt
  log "Installing required base packages..."
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates apt-transport-https gnupg docker.io
}

# Install and configure Docker
install_docker() {
  if command_exists docker; then
    log "Docker is already installed."
  else
    error "Docker command not found after package installation."
    exit 1
  fi

  # Enable and start Docker service
  log "Ensuring Docker service is enabled and running..."
  sudo systemctl enable docker
  sudo systemctl start docker

  # Add current user to docker group (to avoid using sudo for docker commands)
  if groups "$USER" | grep -q '\bdocker\b'; then
    log "User '$USER' is already in the docker group."
  else
    log "Adding user '$USER' to the docker group..."
    sudo usermod -aG docker "$USER"
  fi

  # Validate Docker access
  log "Validating Docker daemon access..."
  sg docker -c "docker ps" >/dev/null 2>&1 || {
    error "Docker daemon is not accessible."
    exit 1
  }
}

# Install kubectl CLI if not already present
install_kubectl() {
  if command_exists kubectl; then
    log "kubectl is already installed."
    return
  fi

  log "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo install kubectl /usr/local/bin/kubectl
  rm -f kubectl
}

# Install Minikube if not already present
install_minikube() {
  if command_exists minikube; then
    log "Minikube is already installed."
    return
  fi

  log "Installing Minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f minikube-linux-amd64
}

# Start Minikube cluster if not already running
start_minikube() {
  local host_status=""
  local kubelet_status=""
  local apiserver_status=""

  # Check if Minikube is already running
  if sg docker -c "minikube status" >/dev/null 2>&1; then
    host_status="$(sg docker -c "minikube status --format='{{.Host}}'" 2>/dev/null || true)"
    kubelet_status="$(sg docker -c "minikube status --format='{{.Kubelet}}'" 2>/dev/null || true)"
    apiserver_status="$(sg docker -c "minikube status --format='{{.APIServer}}'" 2>/dev/null || true)"

    # If fully running, skip start
    if [[ "$host_status" == "Running" && "$kubelet_status" == "Running" && "$apiserver_status" == "Running" ]]; then
      log "Minikube is already running."
      return
    fi
  fi

  # Start Minikube with Docker driver and configured resources
  log "Starting Minikube with Docker driver..."
  sg docker -c "minikube start --driver=docker --memory=${MINIKUBE_MEMORY} --cpus=${MINIKUBE_CPUS}"
}

# Wait until the Kubernetes node becomes Ready
wait_for_cluster() {
  log "Waiting for Kubernetes node to become Ready..."
  kubectl wait --for=condition=Ready node/minikube --timeout=180s
}

# Enable required Minikube addons:
# - ingress (for external access)
# - metrics-server (for HPA/autoscaling)
enable_addons() {
  log "Enabling ingress addon..."
  sg docker -c "minikube addons enable ingress"

  log "Enabling metrics-server addon..."
  sg docker -c "minikube addons enable metrics-server"
}

# Wait until addons (ingress controller and metrics server) are ready
wait_for_addons() {
  log "Waiting for ingress controller to be ready..."
  kubectl wait \
    --namespace ingress-nginx \
    --for=condition=ready pod \
    -l app.kubernetes.io/component=controller \
    --timeout=180s

  log "Waiting for metrics-server to be ready..."
  kubectl wait \
    --namespace kube-system \
    --for=condition=ready pod \
    -l k8s-app=metrics-server \
    --timeout=180s
}

# Show current cluster and addon status for verification/debugging
show_status() {
  log "Minikube status:"
  sg docker -c "minikube status" || true

  log "Kubernetes nodes:"
  kubectl get nodes || true

  log "Ingress pods:"
  kubectl get pods -n ingress-nginx || true

  log "Metrics server pods:"
  kubectl get pods -A | grep metrics || true
}

# Main setup flow:
# Prepares full local Kubernetes environment from scratch
main() {
  ensure_sudo
  wait_for_cloud_init
  disable_apt_background_services
  install_base_packages
  install_docker
  install_kubectl
  install_minikube
  start_minikube
  wait_for_cluster
  enable_addons
  wait_for_addons
  show_status

  log "Setup completed successfully."
  echo
  echo "Next steps:"
  echo "1. Run ./scripts/deploy.sh"
  echo "2. Verify the application with Ingress"
}

# Script entry point
main "$@"
