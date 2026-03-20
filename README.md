# DevOps Homework – Kubernetes Deployment with Minikube

## 📌 Project Overview

This project demonstrates a complete DevOps workflow for deploying a containerized application to a Kubernetes cluster using Minikube.
It includes environment setup, application containerization, Kubernetes manifests, automation scripts, and CI/CD pipeline integration.

The deployed application is a simple web service that returns the current server date and time.

---

## 🏗️ Architecture

* **EC2 Ubuntu instance**
* **Docker** – containerization
* **Minikube (Docker driver)** – local Kubernetes cluster
* **Kubernetes resources**:

  * Deployment (2 replicas)
  * Service (ClusterIP)
  * Ingress (NGINX)
  * Horizontal Pod Autoscaler (HPA)
* **GitHub Actions** – CI/CD pipeline

---

## 📁 Project Structure

```
devops-homework/
├── app/
│   ├── app.py
│   └── requirements.txt
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
├── scripts/
│   ├── setup-minikube.sh
│   └── deploy.sh
├── .github/
│   └── workflows/
│       └── ci-cd.yml
├── Dockerfile
├── .dockerignore
├── .gitignore
├── README.md
└── REPORT.md
```

---

## ⚙️ Prerequisites

* Ubuntu (EC2 or local)
* Internet access
* Git

---

## 🚀 Setup Instructions

### 1. Clone repository

```bash
git clone https://github.com/sequenceXYZ/devops-homework.git
cd devops-homework
```

---

### 2. Setup Kubernetes environment

```bash
chmod +x scripts/setup-minikube.sh
./scripts/setup-minikube.sh
```

This script:

* installs Docker, kubectl, Minikube
* starts Kubernetes cluster
* enables Ingress and metrics-server
* waits until all components are ready

---

### 3. Deploy application

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

This script:

* builds Docker image
* loads image into Minikube
* deploys Kubernetes manifests
* waits for rollout and endpoints
* tests application via Ingress

---

## 🌐 Access Application

### From EC2 (via curl)

```bash
curl -H "Host: datetime.local" http://$(minikube ip)
```

### Expected output:

```
2026-03-20 10:45:00
```

---

## 📊 Kubernetes Resources

### Deployment

* 2 replicas
* health checks (liveness & readiness)
* resource limits

### Service

* ClusterIP
* internal communication

### Ingress

* host: `datetime.local`
* NGINX controller

### HPA

* CPU-based autoscaling
* min: 2 pods
* max: 5 pods

---

## 🔄 CI/CD (GitHub Actions)

### CI Pipeline

* build Docker image
* validate code

### CD Pipeline

* deploy to Kubernetes (Minikube simulation)

---

## 🧪 Testing

* `kubectl get pods`
* `kubectl top pods`
* `curl via Ingress`

---

## ⚠️ Notes

* Application time depends on server (EC2 or local machine)
* Minikube runs inside Docker
* Ingress requires Host header

---

## 🧠 Key Decisions

* Used Minikube for lightweight Kubernetes
* Automated setup and deployment scripts
* Implemented readiness checks for stability
* Used EndpointSlice-aware validation for modern Kubernetes

---

## ✅ Result

* Fully automated deployment
* No manual steps required
* Application accessible via Ingress
* Scalable via HPA

---

## 📄 Report

See `REPORT.md` for detailed explanation and analysis.
