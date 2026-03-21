# DevOps Homework – CI/CD Pipeline with Kubernetes (Minikube)

## 📌 Project Overview

This project demonstrates a fully automated DevOps workflow for deploying a containerized web application to a local Kubernetes cluster using Minikube.

The solution includes:
- Automated environment setup on a fresh Ubuntu machine
- Docker image build and management
- Kubernetes deployment (Deployment, Service, Ingress, HPA)
- CI/CD pipeline using GitHub Actions
- Self-hosted runner for local cluster deployment
- Automatic application verification

---

## 🏗️ Architecture

Workflow:
1. GitHub Actions pipeline is triggered (push or manual)
2. Self-hosted runner executes pipeline
3. Environment is prepared (Docker, Minikube, kubectl)
4. Docker image is built
5. Image is deployed to Kubernetes
6. Application is exposed via Ingress
7. Deployment is verified via HTTP request
8. Image is pushed to Docker Hub

---

## ⚙️ Technologies Used

- Docker
- Kubernetes (Minikube)
- GitHub Actions (CI/CD)
- Self-hosted runner
- Linux (Ubuntu)
- Bash scripting

---

## 📂 Project Structure

devops-homework/

scripts/
- setup-minikube.sh
- deploy.sh
  
k8s/
- deployment.yaml
- service.yaml
- ingress.yaml
- hpa.yaml
  
.github/workflows/
- ci-cd.yml
  
Dockerfile  
README.md  
REPORT.md

---

## 🚀 How to Run (Manual)

### 1. Clone repository

git clone https://github.com/sequenceXYZ/devops-homework.git  
cd devops-homework  

---

### 2. Setup environment

chmod +x scripts/setup-minikube.sh  
./scripts/setup-minikube.sh  

---

### 3. Deploy application

chmod +x scripts/deploy.sh  
./scripts/deploy.sh  

---

### 4. Test application

curl -H "Host: datetime.local" http://$(minikube ip)

---

## 🔄 CI/CD Pipeline

Pipeline is defined in:

.github/workflows/ci-cd.yml

Pipeline steps:
1. Checkout repository  
2. Prepare environment (Docker + Minikube)  
3. Build Docker image  
4. Deploy to Kubernetes  
5. Verify deployment  
6. Push image to Docker Hub  

---

## 🐳 Docker Hub

Docker image is pushed automatically to:

https://hub.docker.com/repositories/<your-username>/datetime-app

Tags:
- latest  
- commit SHA  

---

## 🌐 Access Application

Application is available via Ingress:

curl -H "Host: datetime.local" http://$(minikube ip)

---

## 📈 Scalability

Horizontal Pod Autoscaler (HPA) is configured.

### Manual scaling

kubectl scale deployment datetime-app --replicas=3

### Benefits

- Improved performance  
- High availability  
- Efficient resource usage  

---

## 🔐 Security

- Containers run as non-root user  
- Privilege escalation is disabled  
- Secrets are stored in GitHub Secrets  
- Limited container permissions  
- Controlled CI/CD execution  

---

## 🛠 Troubleshooting

### Docker permission denied

newgrp docker  

---

### Minikube reset

minikube delete  
minikube start --driver=docker  

---

### Check user

whoami  

---

### Pods debugging

kubectl get pods  
kubectl describe pod <pod-name>  
kubectl logs <pod-name>  

---

### Deployment issues

kubectl rollout status deployment datetime-app  
kubectl rollout restart deployment datetime-app  

---

### Service issues

kubectl get svc  
kubectl get endpoints  

---

### Ingress issues

minikube addons enable ingress  
kubectl get ingress  

---

### Full reset

minikube delete  
docker system prune -af  

---

## ⚠️ Important Notes

- The pipeline uses a self-hosted runner  
- Docker access is handled via docker group (sg docker)  
- Minikube runs with Docker driver  
- Setup script handles:
  - cloud-init wait  
  - apt lock issues  
  - background services  

---

## ✅ Features Implemented

- Full environment bootstrap from scratch  
- Automated Kubernetes deployment  
- Ingress-based routing  
- Horizontal Pod Autoscaler (HPA)  
- CI/CD pipeline with GitHub Actions  
- Docker image publishing  
- End-to-end validation  
