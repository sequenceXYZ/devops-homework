#!/usr/bin/env bash

set -euo pipefail

MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-2200}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-2}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.31.0}"

log() {
  echo
  echo "[INFO] $1"
}

warn() {
  echo
  echo "[WARN] $1"
}

error() {
  echo
  echo "[ERROR] $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_sudo() {
  if ! command_exists sudo; then
    error "sudo is required but not installed."
    exit 1
  fi
}

install_base_packages() {
  log "Installing required base packages..."
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates apt-transport-https gnupg
}

install_docker() {
  if command_exists docker; then
    log "Docker is already installed."
  else
    log "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
  fi

  log "Ensuring Docker service is enabled and running..."
  sudo systemctl enable docker
  sudo systemctl start docker

  if groups "$USER" | grep -q '\bdocker\b'; then
    log "User '$USER' is already in the docker group."
  else
    log "Adding user '$USER' to the docker group..."
    sudo usermod -aG docker "$USER"
  fi
}

ensure_docker_access() {
  log "Checking Docker access..."

  if docker ps >/dev/null 2>&1; then
    log "Docker is accessible for user '$USER'."
    return 0
  fi

  warn "Current shell does not yet have Docker group access."
  warn "Attempting to re-run the script in a Docker-group shell..."

  if sg docker -c "docker ps >/dev/null 2>&1"; then
    exec sg docker "$0"
  fi

  error "Docker is installed, but current user still cannot access Docker daemon."
  error "Please start a new login session and rerun the script."
  exit 1
}

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

start_minikube() {
  local host_status=""
  local kubelet_status=""
  local apiserver_status=""

  if minikube status >/dev/null 2>&1; then
    host_status="$(minikube status --format='{{.Host}}' 2>/dev/null || true)"
    kubelet_status="$(minikube status --format='{{.Kubelet}}' 2>/dev/null || true)"
    apiserver_status="$(minikube status --format='{{.APIServer}}' 2>/dev/null || true)"

    if [[ "$host_status" == "Running" && "$kubelet_status" == "Running" && "$apiserver_status" == "Running" ]]; then
      log "Minikube is already running."
      return
    fi
  fi

  log "Starting Minikube with Docker driver..."
  minikube start --driver=docker --memory="${MINIKUBE_MEMORY}" --cpus="${MINIKUBE_CPUS}"
}

wait_for_cluster() {
  log "Waiting for Kubernetes node to become Ready..."
  kubectl wait --for=condition=Ready node/minikube --timeout=180s
}

enable_addons() {
  log "Enabling ingress addon..."
  minikube addons enable ingress

  log "Enabling metrics-server addon..."
  minikube addons enable metrics-server
}

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

show_status() {
  log "Minikube status:"
  minikube status || true

  log "Kubernetes nodes:"
  kubectl get nodes || true

  log "Ingress pods:"
  kubectl get pods -n ingress-nginx || true

  log "Metrics server pods:"
  kubectl get pods -A | grep metrics || true
}

main() {
  ensure_sudo
  install_base_packages
  install_docker
  ensure_docker_access
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

main "$@"
