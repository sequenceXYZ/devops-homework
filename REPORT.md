# DevOps Homework Report
## CI/CD Pipeline with Kubernetes (Minikube)

---

## 1. Introduction

The aim of this project is to design and implement an automated deployment process for a containerized web application using modern DevOps practices. The solution demonstrates a complete CI/CD pipeline that builds, deploys, and verifies an application in a Kubernetes environment.

The project focuses on:

- Infrastructure automation  
- Containerization  
- Continuous Integration and Continuous Deployment (CI/CD)  
- Kubernetes-based application deployment  

---

## 2. Objective

The main objective of this project is to implement a fully automated deployment pipeline that:

- Builds a Docker image of a web application  
- Deploys the application to a Kubernetes cluster  
- Exposes the application via Ingress  
- Verifies the deployment automatically  
- Pushes the Docker image to a container registry  

---

## 3. Technologies Used

The following technologies were used in this project:

- Docker – containerization of the application  
- Kubernetes (Minikube) – orchestration platform  
- GitHub Actions – CI/CD pipeline  
- Self-hosted runner – execution environment  
- Ubuntu Linux – deployment environment  
- Bash scripting – automation  
- Docker Hub – container registry  

---

## 4. System Architecture

The solution is based on a CI/CD pipeline integrated with a Kubernetes cluster running locally via Minikube.

### Workflow

1. Developer pushes code to GitHub repository  
2. GitHub Actions pipeline is triggered  
3. Self-hosted runner executes pipeline steps  
4. Environment is prepared automatically  
5. Docker image is built  
6. Image is deployed to Kubernetes cluster  
7. Application is exposed via Ingress  
8. Deployment is verified via HTTP request  
9. Docker image is pushed to Docker Hub  

The solution was tested on a fresh Ubuntu instance to ensure that the entire deployment process works automatically from scratch without manual intervention. This guarantees reproducibility and validates that all setup, deployment, and verification steps are fully automated.

---

## 5. Implementation

### 5.1 Environment Setup

A Bash script (`setup-minikube.sh`) was created to automate environment preparation. The script performs:

- Waiting for cloud-init completion  
- Disabling background package update services  
- Installing required packages (Docker, kubectl, Minikube)  
- Starting Minikube cluster using Docker driver  
- Enabling Kubernetes addons (Ingress, metrics-server)  

Special handling was implemented to resolve:

- apt/dpkg lock issues  
- background update conflicts  
- Docker permission handling  

---

### 5.2 Application Deployment

The deployment process is implemented in `deploy.sh`.

The script performs:

- Docker image build  
- Loading image into Minikube  
- Applying Kubernetes manifests  
- Waiting for deployment rollout  
- Verifying service endpoints  
- Testing application via Ingress  

The application is exposed using:

- Kubernetes Service (ClusterIP)  
- Ingress resource with hostname routing  

---

### 5.3 Kubernetes Resources

The following Kubernetes components were implemented:

- Deployment – manages application pods  
- Service – provides internal access  
- Ingress – exposes application externally  
- Horizontal Pod Autoscaler (HPA) – enables scaling based on CPU  

---

### 5.4 CI/CD Pipeline

The CI/CD pipeline is defined using GitHub Actions.

### Pipeline steps

1. Checkout repository  
2. Prepare environment (setup script)  
3. Deploy application (deploy script)  
4. Verify deployment  
5. Log in to Docker Hub  
6. Tag Docker image  
7. Push image to Docker Hub  

A self-hosted runner is used because:

- deployment is performed on a local Kubernetes cluster  
- GitHub-hosted runners cannot access local infrastructure  

---

### 5.5 Docker Image Management

The application is containerized using Docker.

Pipeline performs:

- image build  
- tagging (latest and commit SHA)  
- pushing to Docker Hub  

This ensures version control and reproducibility.

---

## 6. Process and Design Decisions

During the implementation of this project, several technical decisions were made to ensure stability, automation, and reproducibility.

### Choice of Kubernetes Environment

Minikube was selected because:

- it allows running a local cluster  
- it is suitable for development and testing  
- it integrates well with Docker  

### Use of Self-hosted Runner

A self-hosted runner was used because:

- deployment requires access to a local Kubernetes cluster  
- GitHub-hosted runners cannot access local infrastructure  
- it provides full control over execution environment  

### Docker Driver Selection

Minikube was configured with Docker driver because:

- it simplifies setup  
- no virtual machine required  
- better performance  

### Automation via Bash Scripts

Two scripts were created:

- setup-minikube.sh  
- deploy.sh  

This ensures:

- modular design  
- reusability  
- easier debugging  

### Handling System-Level Issues

Several real-world issues were solved:

- apt/dpkg locks → handled with waiting logic  
- background services → disabled  
- Docker permissions → solved using sg docker  
- working directory issues → dynamically resolved  

### CI/CD Design

The pipeline was designed to:

- separate setup and deployment  
- verify deployment before push  
- ensure reliability  

---

## 7. Horizontal Scaling

Horizontal scaling is implemented using Kubernetes Horizontal Pod Autoscaler (HPA).

### Configuration

- Minimum replicas: 2  
- Maximum replicas: 5  
- Target CPU utilization: 50%  

### Scaling Behavior

- Pods increase when CPU usage rises  
- Pods decrease when load drops  

### Manual Scaling

kubectl scale deployment datetime-app --replicas=3  

### Benefits

- improved performance  
- high availability  
- efficient resource usage  

---

## 8. Security Considerations

Several security aspects were considered.

### Container Security

- Application runs in isolated Docker container  
- Minimal image content used  

### Access Control

- Docker access via docker group  
- No unnecessary root execution  
- Controlled command execution  

### Secrets Management

- Docker Hub credentials stored in GitHub Secrets  
- No sensitive data stored in repository  

### Network Security

- Application exposed via Ingress  
- Internal communication via ClusterIP  
- Host-based routing used  

### CI/CD Security

- Controlled execution via self-hosted runner  
- Trusted code execution  
- Secure secret injection  

### System-Level Security

- Background services controlled  
- Safe package installation  

---

## 9. Results

The project successfully demonstrates:

- automated environment setup from scratch  
- working Kubernetes deployment  
- functional Ingress access  
- CI/CD pipeline execution  
- Docker image push to Docker Hub  
- successful end-to-end validation  

---

## 10. Conclusion

This project demonstrates a complete DevOps workflow combining:

- containerization  
- orchestration  
- automation  

The solution ensures:

- reproducibility  
- scalability  
- reliability  

Using a self-hosted runner enabled integration with local infrastructure, which reflects real-world DevOps scenarios.

---

## 11. References

- Docker Documentation  
- Kubernetes Documentation  
- GitHub Actions Documentation  
- Minikube Documentation  
