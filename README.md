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
