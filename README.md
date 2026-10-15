# Tech Challenge 2 — Application Deployment with Docker, Terraform, EKS, Jenkins, GitHub Actions, and Argo CD

## Project Overview

This project demonstrates two complete deployment approaches for a simple containerized web application running on Amazon Elastic Kubernetes Service (EKS).

The application is a Python Flask service. Its final GitOps-verified response is:

```text
Hello from Tech Challenge 2! It's your host JCloud! GitOps fully automated deployment verified!
```

The purpose of the project is not application complexity. The focus is the infrastructure and deployment workflow surrounding the application.

The project demonstrates:

- Docker containerization
- Amazon Elastic Container Registry (ECR)
- Infrastructure as Code with Terraform
- Amazon EKS
- Kubernetes Deployments and Services
- Helm
- AWS Load Balancer Controller
- Internet-facing Application Load Balancer (ALB)
- Kubernetes Horizontal Pod Autoscaler (HPA)
- EKS worker-node autoscaling
- Jenkins CI/CD
- GitHub Actions CI
- Argo CD GitOps deployment
- Immutable container-image versioning with Git commit SHAs

Two deployment models are maintained in separate Git branches:

```text
main
└── Traditional Jenkins CI/CD

gitops
└── GitHub Actions + Argo CD GitOps
```

The `main` branch demonstrates a push-based deployment workflow where Jenkins builds the application and directly deploys it to EKS using Helm.

The `gitops` branch demonstrates a GitOps workflow where GitHub Actions builds and publishes container images, Git records the desired deployment version, and Argo CD reconciles EKS with the desired state stored in Git.

---

# Architecture

## Submission architecture diagrams

The diagrams are supplied as editable Graphviz `.dot` sources and rendered `.svg`/`.png` assets in `docs/diagrams/`:

![Jenkins and GitOps delivery paths](docs/diagrams/ci-cd-architecture.svg)

![AWS network and Kubernetes topology](docs/diagrams/aws-network-architecture.svg)

These diagrams represent the verified deployment design; AWS-managed components are shown at a logical level rather than as an exhaustive inventory of Terraform resources.


## Shared AWS Architecture

Both deployment implementations use the same general AWS platform:

```text
                         Internet
                            |
                            v
                AWS Application Load Balancer
                            |
                            v
                    Kubernetes Ingress
                            |
                            v
                    Kubernetes Service
                            |
                            v
                  Kubernetes Deployment
                            |
                            v
                      Flask Pod(s)
                            |
                            v
                    Docker Container
```

The supporting infrastructure includes:

```text
AWS
├── VPC
│   ├── Public Subnet — AZ 1
│   ├── Public Subnet — AZ 2
│   ├── Private Subnet — AZ 1
│   └── Private Subnet — AZ 2
│
├── EKS Cluster
│   └── Managed Node Group
│       ├── Instance type: t3.small
│       ├── Minimum nodes: 1
│       ├── Desired nodes: 1
│       └── Maximum nodes: 4
│
├── Amazon ECR
│   └── tech-challenge-2-app
│
└── Application Load Balancer
    └── Created through the AWS Load Balancer Controller
```

Application worker nodes run in private subnets.

The internet-facing ALB uses public subnets.

---

# Jenkins Deployment Architecture

The `main` branch uses Jenkins for both CI and CD.

```text
Developer
   |
   v
GitHub — main
   |
   v
Jenkins
   |
   +--> Checkout source code
   |
   +--> Build Docker image
   |
   +--> Authenticate to AWS
   |
   +--> Authenticate to ECR
   |
   +--> Tag image with Git SHA
   |
   +--> Push image to ECR
   |
   +--> Connect to EKS
   |
   +--> Helm upgrade --install
   |
   +--> Verify Kubernetes rollout
   |
   v
Amazon EKS
   |
   v
ALB
   |
   v
Application
```

Jenkins actively pushes deployment changes into EKS.

---

# GitOps Deployment Architecture

The `gitops` branch separates CI from deployment.

```text
Developer
   |
   v
GitHub — gitops
   |
   v
GitHub Actions
   |
   +--> Build Docker image
   |
   +--> Authenticate to AWS using OIDC
   |
   +--> Push image to ECR
   |
   +--> Update Helm image tag in Git
   |
   +--> Commit desired-state change
   |
   v
Git Repository
   |
   v
Argo CD
   |
   +--> Read gitops branch
   |
   +--> Render Helm chart
   |
   +--> Compare Git state with EKS state
   |
   +--> Reconcile differences
   |
   v
Amazon EKS
   |
   v
ALB
   |
   v
Application
```

GitHub Actions does not run `kubectl`, `helm upgrade`, or directly deploy into EKS.

Git acts as the source of truth.

Argo CD is responsible for deployment reconciliation.

---

# Prerequisites

The following tools are required for local administration and deployment:

- Git
- GitHub account
- Docker / Docker Desktop
- Python 3
- AWS CLI v2
- Terraform
- kubectl
- Helm
- eksctl
- Argo CD CLI
- An AWS account with permissions to create the required infrastructure

Recommended local environment:

```text
macOS or Linux
AWS CLI configured
Docker running
Git authenticated with GitHub
```

Verify tools with:

```bash
git --version
docker --version
python3 --version
aws --version
terraform version
kubectl version --client
helm version
eksctl version
argocd version --client
```

Before deploying AWS resources, verify the AWS identity:

```bash
aws sts get-caller-identity
```

---

# Repository Structure

```text
tech-challenge-2/
├── .github/
│   └── workflows/
│       └── build.yml
│
├── app/
│   ├── app.py
│   └── requirements.txt
│
├── argocd/
│   └── application.yaml
│
├── helm/
│   └── tech-challenge-2/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── hpa.yaml
│
├── kubernetes/
│   ├── deployment.yaml
│   └── service.yaml
│
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── ecr.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── .dockerignore
├── .gitignore
├── Dockerfile
├── Jenkinsfile
└── README.md
```

The raw Kubernetes manifests are retained to document the initial manual deployment process.

The Helm chart is the primary deployment configuration after the manual Kubernetes validation phase.

---

# Application Setup

The application is intentionally simple.

Example `app/app.py`:

```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello, World!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

The application listens on:

```text
0.0.0.0:5000
```

Using `0.0.0.0` is important because the Flask process must accept traffic coming from outside the container.

Install dependencies locally:

```bash
cd app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Run:

```bash
python app.py
```

Test:

```bash
curl http://localhost:5000
```

Expected response:

```text
Hello, World!
```

Stop the application with:

```text
Ctrl+C
```

---

# Docker Build and Run

The root `Dockerfile` packages the Flask application.

Example:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 5000

CMD ["python", "app.py"]
```

Build locally:

```bash
docker build -t tech-challenge-2-app:local .
```

Run:

```bash
docker run \
  --name tech-challenge-2-container \
  -p 5000:5000 \
  tech-challenge-2-app:local
```

Test:

```bash
curl http://localhost:5000
```

Expected:

```text
Hello, World!
```

The EKS worker nodes use `t3.small`, which are AMD64 instances.

When building from an ARM-based development machine such as Apple Silicon, build an AMD64-compatible image before pushing to ECR:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t tech-challenge-2-app:v1 \
  --load \
  .
```

Verify:

```bash
docker image inspect \
  tech-challenge-2-app:v1 \
  --format '{{.Architecture}}'
```

Expected:

```text
amd64
```

---

# Terraform Infrastructure

Terraform provisions the AWS infrastructure required by the project.

The Terraform configuration includes:

- VPC
- Public subnets
- Private subnets
- NAT Gateway
- EKS control plane
- EKS managed node group
- IAM resources
- Amazon ECR repository
- Supporting networking and security configuration

Navigate to:

```bash
cd terraform
```

Initialize Terraform:

```bash
terraform init
```

Format:

```bash
terraform fmt -recursive
```

Validate:

```bash
terraform validate
```

Review the execution plan:

```bash
terraform plan -out=tfplan
```

Apply:

```bash
terraform apply tfplan
```

Terraform state files should not be committed to Git.

Typical `.gitignore` entries include:

```text
.terraform/
*.tfstate
*.tfstate.*
tfplan
*.tfvars
```

The Terraform dependency lock file should generally be committed:

```text
.terraform.lock.hcl
```

This improves reproducibility of provider versions.

---

# VPC Configuration

The project uses two Availability Zones.

Example network layout:

```text
VPC
10.0.0.0/16

Public:
10.0.1.0/24
10.0.2.0/24

Private:
10.0.10.0/24
10.0.20.0/24
```

Public subnets are tagged for internet-facing load balancer discovery.

Private subnets are tagged for internal Kubernetes load-balancer discovery.

Example:

```hcl
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"
}
```

EKS worker nodes run in the private subnets.

---

# EKS Configuration

The EKS cluster is provisioned through Terraform.

The managed node group uses:

```text
Instance type: t3.small

Minimum nodes: 1
Desired nodes: 1
Maximum nodes: 4
```

Example Terraform configuration:

```hcl
eks_managed_node_groups = {
  main = {
    name           = "${var.project_name}-nodes"
    instance_types = ["t3.small"]

    min_size     = 1
    desired_size = 1
    max_size     = 4
  }
}
```

After Terraform completes, configure local Kubernetes access:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name tech-challenge-2-cluster
```

Verify:

```bash
kubectl config current-context
```

Then:

```bash
kubectl get nodes
```

Nodes should report:

```text
Ready
```

---

# Amazon ECR Configuration

Terraform creates the private container repository:

```text
tech-challenge-2-app
```

Example ECR repository URL:

```text
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2-app
```

Authenticate Docker:

```bash
aws ecr get-login-password \
  --region us-east-1 \
| docker login \
  --username AWS \
  --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

Tag:

```bash
docker tag \
  tech-challenge-2-app:v1 \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2-app:v1
```

Push:

```bash
docker push \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2-app:v1
```

Verify:

```bash
aws ecr describe-images \
  --repository-name tech-challenge-2-app \
  --region us-east-1
```

Both automated pipelines use immutable Git commit SHAs as image tags.

Example:

```text
tech-challenge-2-app:a91c57f
```

This provides traceability between:

```text
Git commit
=
ECR artifact
=
EKS image
```

---

# Kubernetes Deployment

Raw Kubernetes manifests were initially used to prove that the application could run successfully before adding Helm and CI/CD automation.

The Deployment defines:

- Container image
- Port 5000
- CPU requests and limits
- Memory requests and limits

Example resource configuration:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
```

The Service exposes the application internally:

```text
Service port: 80
Container target port: 5000
Service type: ClusterIP
```

Apply manually:

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```

Verify:

```bash
kubectl get deployments
kubectl get pods
kubectl get svc
```

Test through port forwarding:

```bash
kubectl port-forward \
  service/tech-challenge-2-service \
  8080:80
```

Then:

```bash
curl http://localhost:8080
```

Expected:

```text
Hello, World!
```

The raw manifests are retained as documentation, but Helm is used for the final deployment workflow.

---

# Helm Deployment

The chart is stored under:

```text
helm/tech-challenge-2/
```

Helm templates:

- Deployment
- Service
- Ingress
- HorizontalPodAutoscaler

Validate the chart:

```bash
helm lint ./helm/tech-challenge-2
```

Render locally:

```bash
helm template \
  hello-world \
  ./helm/tech-challenge-2
```

Install:

```bash
helm install \
  hello-world \
  ./helm/tech-challenge-2
```

Upgrade:

```bash
helm upgrade \
  hello-world \
  ./helm/tech-challenge-2
```

The CI/CD pipeline uses:

```bash
helm upgrade --install \
  hello-world \
  ./helm/tech-challenge-2 \
  --set image.repository=<ECR_REPOSITORY> \
  --set image.tag=<IMAGE_TAG>
```

The release name is:

```text
hello-world
```

Resource naming therefore uses:

```text
hello-world-tech-challenge-2
```

Example Helm commands:

```bash
helm list
helm status hello-world
helm history hello-world
helm get manifest hello-world
```

---

# AWS Load Balancer Controller

The AWS Load Balancer Controller monitors Kubernetes Ingress resources and creates AWS load-balancing resources.

The controller runs in:

```text
kube-system
```

It requires AWS IAM permissions.

The challenge implementation uses a dedicated Kubernetes ServiceAccount integrated with an AWS IAM role.

Conceptually:

```text
Ingress
   |
   v
AWS Load Balancer Controller
   |
   v
AWS APIs
   |
   v
Application Load Balancer
```

Verify controller health:

```bash
kubectl get deployment \
  aws-load-balancer-controller \
  -n kube-system
```

Check Pods:

```bash
kubectl get pods -n kube-system
```

If troubleshooting:

```bash
kubectl logs \
  -n kube-system \
  deployment/aws-load-balancer-controller
```

---

# ALB Configuration

The Helm Ingress configures the public load balancer.

Example:

```yaml
ingress:
  enabled: true
  className: alb

  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
```

The Ingress uses:

```text
internet-facing
```

for a public ALB.

The target type is:

```text
ip
```

which allows the ALB to route directly to Pod IP addresses.

Verify:

```bash
kubectl get ingress
```

Describe:

```bash
kubectl describe ingress \
  hello-world-tech-challenge-2
```

Inspect target health through AWS if needed.

---

# Horizontal Pod Autoscaler

The project uses Kubernetes HPA with both CPU and memory metrics.

Configuration:

```text
Minimum replicas: 1
Maximum replicas: 3

CPU target: 50%
Memory target: 50%
```

Example:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 50
  targetMemoryUtilizationPercentage: 50
```

Multiple metrics are evaluated independently.

The HPA can increase replicas when either CPU or memory utilization requires more capacity.

Resource utilization is calculated relative to container resource requests.

Verify:

```bash
kubectl get hpa
```

Detailed status:

```bash
kubectl describe hpa \
  hello-world-tech-challenge-2
```

Metrics:

```bash
kubectl top pods
kubectl top nodes
```

Metrics Server must be installed and healthy for HPA resource metrics.

Important:

```text
maxReplicas: 3
```

means a maximum of three Pods for the workload as a whole.

It does not mean three Pods per Kubernetes node.

---

# Node Autoscaling

Pod autoscaling and node autoscaling solve different problems.

```text
HPA
→ increases or decreases Pods

Cluster Autoscaler
→ increases or decreases worker nodes
```

The EKS managed node group permits:

```text
Minimum: 1
Maximum: 4
```

The Cluster Autoscaler detects Pods that cannot be scheduled because of insufficient node capacity.

Conceptually:

```text
Traffic increases
      |
      v
HPA requests more Pods
      |
      v
Kubernetes Scheduler
      |
      v
Pod cannot fit
      |
      v
Pending Pod
      |
      v
Cluster Autoscaler
      |
      v
Managed Node Group desired size increases
      |
      v
New EC2 node joins EKS
      |
      v
Pending Pod scheduled
```

Verify:

```bash
kubectl get nodes
```

Cluster Autoscaler:

```bash
kubectl get deployment \
  cluster-autoscaler \
  -n kube-system
```

Logs:

```bash
kubectl logs \
  -n kube-system \
  deployment/cluster-autoscaler
```

The managed node group's `min_size` and `max_size` establish the scaling boundaries.

The autoscaler dynamically changes desired capacity within those boundaries.

---

# Jenkins Setup

The traditional CI/CD implementation runs on the `main` branch.

Jenkins runs on a dedicated EC2 instance separate from the EKS worker nodes.

The Jenkins server requires:

- Java
- Jenkins
- Git
- Docker
- AWS CLI
- kubectl
- Helm

Jenkins runs under the Linux account:

```text
jenkins
```

The Jenkins user must be able to invoke Docker.

Example:

```bash
sudo usermod -aG docker jenkins
```

Restart Jenkins after group changes.

Verify:

```bash
sudo -u jenkins docker version
sudo -u jenkins aws sts get-caller-identity
sudo -u jenkins kubectl get nodes
sudo -u jenkins helm list
```

---

# Jenkins AWS Authentication

Jenkins does not store long-lived AWS access keys.

The Jenkins EC2 instance uses an IAM role.

Conceptually:

```text
Jenkins EC2
   |
   v
Instance Profile
   |
   v
JenkinsEC2Role
   |
   +--> ECR permissions
   |
   +--> EKS DescribeCluster
   |
   └--> EKS Access Entry / Kubernetes permissions
```

Verify from the Jenkins host:

```bash
aws sts get-caller-identity
```

The returned identity should correspond to the Jenkins IAM role.

---

# Jenkins GitHub Authentication

The private GitHub repository can be accessed using a dedicated repository deploy key stored inside Jenkins Credentials.

The private key should never be committed to the repository.

The Jenkins SCM job should point to:

```text
Branch: main
Script path: Jenkinsfile
```

---

# Jenkins Pipeline

The `Jenkinsfile` automates:

```text
Checkout
   ↓
Build Docker image
   ↓
Verify AWS authentication
   ↓
Authenticate to ECR
   ↓
Tag image
   ↓
Push image
   ↓
Connect to EKS
   ↓
Deploy with Helm
   ↓
Verify Kubernetes rollout
```

Docker images use the Git commit SHA.

Example:

```text
Git:
a91c57f

ECR:
tech-challenge-2-app:a91c57f

EKS:
tech-challenge-2-app:a91c57f
```

This creates direct source-to-deployment traceability.

Jenkins authenticates with ECR dynamically:

```bash
aws ecr get-login-password \
  --region us-east-1 \
| docker login \
  --username AWS \
  --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

EKS access is configured:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name tech-challenge-2-cluster
```

Deployment:

```bash
helm upgrade --install \
  hello-world \
  ./helm/tech-challenge-2 \
  --set image.repository=<ECR_REPOSITORY> \
  --set image.tag=<GIT_SHA>
```

Verification:

```bash
kubectl rollout status \
  deployment/hello-world-tech-challenge-2
```

The pipeline fails if the Kubernetes Deployment does not successfully roll out.

---

# Jenkins End-to-End Validation

The Jenkins workflow was tested by changing the visible application response.

Example test:

```text
Before:
Hello, World!

After:
Hello from Tech Challenge 2!
```

The test verified:

```text
Git push
→ Jenkins checkout
→ Docker build
→ ECR push
→ Helm upgrade
→ Kubernetes rollout
→ ALB updated
```

The final application response was then restored to:

```text
Hello, World!
```

through the same Jenkins pipeline.

---

# GitHub Actions Workflow

The GitOps implementation exists on:

```text
gitops
```

GitHub Actions is responsible for CI.

Its responsibilities are:

```text
Application change
      |
      v
Build Docker image
      |
      v
Authenticate to AWS
      |
      v
Push image to ECR
      |
      v
Update Helm image tag in Git
```

GitHub Actions does not directly deploy to EKS.

---

# GitHub Actions Trigger

The workflow is limited to the `gitops` branch and container-build inputs.

Example:

```yaml
on:
  workflow_dispatch:

  push:
    branches:
      - gitops
    paths:
      - "app/**"
      - "Dockerfile"
      - ".dockerignore"
```

A README-only change therefore does not unnecessarily rebuild the application.

---

# GitHub Actions AWS Authentication

GitHub Actions uses OpenID Connect federation instead of permanent AWS access keys.

Architecture:

```text
GitHub Actions
      |
      v
GitHub OIDC token
      |
      v
AWS STS
      |
      v
TechChallenge2GitHubActionsRole
      |
      v
Temporary AWS credentials
```

The IAM role is limited primarily to ECR push permissions.

GitHub Actions does not need EKS deployment access.

Workflow permissions include:

```yaml
permissions:
  contents: write
  id-token: write
```

`contents: write` is required because the workflow updates the desired image version in Git.

`id-token: write` is required for AWS OIDC authentication.

---

# GitHub Actions Image Versioning

Images use:

```text
github.sha
```

as the image tag.

Example:

```text
Application commit:
def456abcdef...

ECR image:
tech-challenge-2-app:def456abcdef...
```

After pushing the image, Actions updates:

```text
helm/tech-challenge-2/values.yaml
```

Example:

```yaml
image:
  repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-2-app
  tag: "def456abcdef..."
```

Actions then commits the desired-state update.

This means:

```text
ECR stores the artifact.

Git determines which artifact should run.
```

---

# Argo CD Configuration

Argo CD runs inside the EKS cluster under:

```text
argocd
```

namespace.

Verify:

```bash
kubectl get pods -n argocd
```

The Argo CLI can be installed locally:

```bash
brew install argocd
```

For local access without publicly exposing the Argo API:

```bash
kubectl port-forward \
  svc/argocd-server \
  -n argocd \
  8080:443
```

The GitHub repository is public, and Argo CD reads its `gitops` branch. No private-repository deploy key is required for the public repository.

Argo only needs Git read access.

It does not require ECR push permissions.

---

# Argo CD Application

The application definition is stored at:

```text
argocd/application.yaml
```

Conceptually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: tech-challenge-2-gitops
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/jhjeremy27-web/Tech-Challenge-2.git
    targetRevision: refs/heads/gitops
    path: helm/tech-challenge-2

    helm:
      releaseName: hello-world

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    automated:
      enabled: true
      prune: false
      selfHeal: false
```

The Helm release name remains:

```text
hello-world
```

so Argo renders the same Kubernetes object names that were used by the original Helm deployment.

---

# GitOps Reconciliation

Argo continuously compares:

```text
Desired state in Git
```

with:

```text
Actual state in EKS
```

Example:

```text
Git:
image:def456

EKS:
image:abc123
```

Argo reports:

```text
OutOfSync
```

and reconciles EKS.

After synchronization:

```text
Git:
image:def456

EKS:
image:def456
```

Argo reports:

```text
Synced
Healthy
```

Verify:

```bash
kubectl get application tech-challenge-2-gitops -n argocd
```

---

# Argo Automated Sync

The application uses:

```yaml
automated:
  enabled: true
  prune: false
  selfHeal: false
```

`enabled` automatically synchronizes Git changes.

`prune: false` means automatic synchronization does **not** automatically delete resources removed from Git.

`selfHeal: false` means live-cluster drift alone does **not** trigger automatic correction; new Git revisions still trigger automated synchronization.

For the `gitops` branch, direct application deployments with:

```text
helm upgrade
kubectl set image
```

should not be used as the normal deployment method.

Deployment changes should flow through Git.

---

# Complete GitOps Workflow

The completed GitOps workflow is:

```text
Developer modifies Flask application
              |
              v
git push to gitops
              |
              v
GitHub Actions
              |
              +--> Authenticate to AWS using OIDC
              |
              +--> Build linux/amd64 Docker image
              |
              +--> Tag image with source commit SHA
              |
              +--> Push image to ECR
              |
              +--> Update Helm values.yaml
              |
              +--> Commit desired-state change
              |
              v
GitHub — gitops branch
              |
              v
Argo CD
              |
              +--> Detect Git change
              |
              +--> Render Helm chart
              |
              +--> Compare desired/live state
              |
              +--> Synchronize
              |
              v
EKS
              |
              v
Rolling Deployment
              |
              v
ALB
              |
              v
Updated application
```

---

# GitOps End-to-End Validation

The GitOps flow was validated by changing the application response.

Example:

```text
Before:
Hello, World!

Test:
Hello from GitOps!
```

The following was verified:

```text
GitHub push
→ GitHub Actions
→ Docker image build
→ ECR image push
→ values.yaml update in Git
→ Argo CD detects desired-state change
→ Argo CD reconciles EKS
→ Kubernetes rollout
→ ALB serves updated application
```

No manual Helm, kubectl deployment, or Jenkins execution was required.

The application was then restored to:

```text
Hello, World!
```

through the same GitOps process.

---

# Deployment Instructions — Jenkins / `main`

Switch to:

```bash
git switch main
```

Make an application change.

Review:

```bash
git status
git diff
```

Commit:

```bash
git add .
git commit -m "Update application"
```

Push:

```bash
git push
```

Jenkins performs:

```text
Checkout
Build
ECR Push
EKS Connection
Helm Upgrade
Rollout Verification
```

Verify:

```bash
kubectl get deployment \
  hello-world-tech-challenge-2 \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Verify the ALB endpoint.

---

# Deployment Instructions — GitOps / `gitops`

Switch to:

```bash
git switch gitops
```

Make an application change.

Review:

```bash
git status
git diff
```

Commit:

```bash
git add app/app.py
git commit -m "Update GitOps application"
```

Push:

```bash
git push
```

GitHub Actions automatically:

```text
builds
pushes ECR image
updates Git desired state
```

Argo then automatically:

```text
detects
compares
synchronizes
```

Monitor:

```bash
argocd app get \
  tech-challenge-2 \
  --refresh
```

Check Kubernetes:

```bash
kubectl rollout status \
  deployment/hello-world-tech-challenge-2
```

Then verify the public endpoint.

---

# Public Application URL

The public application is exposed through the AWS Application Load Balancer.

Current deployment URL:

```text
http://<PUBLIC_ALB_DNS_NAME>
```

Replace the placeholder above with the deployed ALB hostname before final submission.

The URL can also be retrieved with:

```bash
kubectl get ingress \
  hello-world-tech-challenge-2 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Test:

```bash
curl http://<PUBLIC_ALB_DNS_NAME>
```

Expected final response at the time of the unattended GitOps test:

```text
Hello from Tech Challenge 2! It's your host JCloud! GitOps fully automated deployment verified!
```

---

# Useful Verification Commands

## AWS Identity

```bash
aws sts get-caller-identity
```

## EKS Nodes

```bash
kubectl get nodes
```

## Application Pods

```bash
kubectl get pods
```

## Kubernetes Service

```bash
kubectl get svc
```

## Ingress

```bash
kubectl get ingress
```

## HPA

```bash
kubectl get hpa
```

## Resource Metrics

```bash
kubectl top pods
kubectl top nodes
```

## Helm Release

```bash
helm list
helm status hello-world
helm history hello-world
```

## Deployment Image

```bash
kubectl get deployment \
  hello-world-tech-challenge-2 \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Kubernetes Rollout

```bash
kubectl rollout status \
  deployment/hello-world-tech-challenge-2
```

## ECR Images

```bash
aws ecr describe-images \
  --repository-name tech-challenge-2-app \
  --region us-east-1
```

## Argo CD

```bash
kubectl get application tech-challenge-2-gitops -n argocd
```

---

# Verified End-to-End Automation (October 2026)

## Jenkins (`main`) — successful automatic trigger

1. GitHub repository webhook was configured with the Jenkins GitHub endpoint `/github-webhook/`.
2. The first GitHub ping failed to connect because the EC2 security group allowed TCP/8080 only from the developer's home IP.
3. Published GitHub webhook IPv4 CIDRs were added as temporary TCP/8080 inbound rules; the redelivery succeeded.
4. A documentation-only commit was pushed to `main` without clicking **Build Now**. Jenkins automatically started and successfully completed its pipeline. A screenshot of the successful build was captured.

The repository's `Jenkinsfile` confirms these stages: checkout verification, Docker build, ECR login and push, EKS kubeconfig setup, Helm upgrade/install, and rollout verification. The Jenkins job webhook trigger is configured in Jenkins, not in the `Jenkinsfile`.

## GitOps (`gitops`) — successful unattended reconciliation

1. The Flask response in `app/app.py` was updated and pushed to `gitops`.
2. GitHub Actions completed successfully and updated the Helm image tag in Git.
3. Without manually refreshing or syncing Argo CD, the Application reached **Synced / Healthy**.
4. The ALB served the updated response:

```text
Hello from Tech Challenge 2! It's your host JCloud! GitOps fully automated deployment verified!
```

Screenshots were captured of the Argo CD state and updated live application. This confirms Git revision detection and automatic deployment for the tested change. An earlier test had required a manual Argo CD hard refresh; the final test did not.

## Verification boundaries

- HPA CPU and memory targets: **50% each**, configured; no load-driven scale-out test claimed.
- EKS managed node group: minimum **1**, maximum **4**, configured; no live node-scale test claimed.
- Jenkins is served over **HTTP** on port **8080** for the lab. Published GitHub webhook CIDRs are permitted through the EC2 security group; this does **not** provide request authentication or transport encryption. Remove temporary ingress rules after evaluation and use HTTPS with appropriate webhook validation for a durable deployment.
- Jenkins and GitOps share the same Helm release/workload. Tests were performed sequentially; avoid concurrent deployments from both paths.

## Submission screenshots

Store screenshots in `docs/screenshots/` and link their actual filenames here once provided. Recommended evidence: GitHub successful webhook delivery, Jenkins automatically triggered successful build, successful GitHub Actions run, Argo CD **Synced / Healthy**, and the ALB's final greeting. Do not add links to screenshots that have not been committed.

---

# Troubleshooting

## Terraform Reports an Empty Directory

Symptom:

```text
Terraform initialized in an empty directory
```

Cause:

Terraform commands were executed outside the directory containing the `.tf` files.

Verify:

```bash
pwd
ls
```

Then:

```bash
cd terraform
terraform init
```

---

## EKS Node Does Not Become Ready

Check:

```bash
kubectl get nodes
```

Then inspect the AWS managed node group:

```bash
aws eks describe-nodegroup \
  --cluster-name tech-challenge-2-cluster \
  --nodegroup-name <NODE_GROUP_NAME> \
  --region us-east-1
```

An AWS node group can report `ACTIVE` while a Kubernetes node still fails to report `Ready`.

These are different health checks.

---

## `kubectl` Reports Unauthorized

First verify AWS identity:

```bash
aws sts get-caller-identity
```

Then verify the EKS Access Entry / Kubernetes authorization for that IAM identity.

An AWS-authenticated principal can still lack Kubernetes permissions.

---

## Docker ImagePullBackOff

Check:

```bash
kubectl describe pod <POD_NAME>
```

Likely causes:

- Wrong ECR repository
- Wrong image tag
- Image does not exist
- Worker-node ECR permissions
- Networking issue

Verify ECR:

```bash
aws ecr describe-images \
  --repository-name tech-challenge-2-app
```

---

## `exec format error`

Likely cause:

An ARM64 image was built locally and deployed to AMD64 `t3.small` worker nodes.

Build:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <IMAGE> \
  --load \
  .
```

---

## CrashLoopBackOff

Check:

```bash
kubectl logs <POD_NAME>
```

Then:

```bash
kubectl describe pod <POD_NAME>
```

This generally indicates an application/container startup failure rather than an ECR or load-balancer issue.

---

## Deployment Works but Service Does Not

Verify labels:

```bash
kubectl get pods --show-labels
```

Inspect Service:

```bash
kubectl describe svc \
  hello-world-tech-challenge-2
```

Check endpoints:

```bash
kubectl get endpoints \
  hello-world-tech-challenge-2
```

The Service selector must match the Pod labels.

---

## Service Works but ALB Does Not

First prove the Service:

```bash
kubectl port-forward \
  service/hello-world-tech-challenge-2 \
  8080:80
```

Then:

```bash
curl http://localhost:8080
```

If this succeeds, focus troubleshooting on:

- Ingress
- AWS Load Balancer Controller
- IAM permissions
- Subnet discovery/tags
- ALB target health
- ALB health-check path

---

## Ingress Has No Address

Run:

```bash
kubectl describe ingress \
  hello-world-tech-challenge-2
```

Then inspect controller logs:

```bash
kubectl logs \
  -n kube-system \
  deployment/aws-load-balancer-controller
```

Common causes:

- AWS IAM permission failure
- Missing subnet tags
- Incorrect IngressClass
- Invalid annotations

---

## ALB Returns 503

Usually indicates:

```text
ALB exists
but no healthy targets are available
```

Check:

- Pod health
- Service selectors
- Target port
- ALB health-check path
- Target group health

---

## HPA Shows Unknown Metrics

Check:

```bash
kubectl top pods
```

If metrics fail, inspect Metrics Server.

Also verify resource requests exist in the Deployment.

HPA percentage-based CPU and memory utilization requires resource requests.

---

## HPA Does Not Scale

If HPA displays valid metrics but remains at one replica, the current workload may simply be below the configured:

```text
50%
```

threshold.

This is not necessarily a failure.

Use controlled load generation when testing autoscaling.

---

## HPA Scales Pods but Node Count Does Not Increase

The additional Pods may still fit on the current `t3.small`.

Node autoscaling only becomes necessary when Pods cannot be scheduled due to insufficient resources.

Look for:

```text
Pending
```

Pods and scheduling events such as:

```text
Insufficient cpu
```

or:

```text
Insufficient memory
```

---

## Jenkins Cannot Use Docker

Symptom:

```text
permission denied while trying to connect to Docker daemon
```

Check:

```bash
groups jenkins
```

Then:

```bash
ls -l /var/run/docker.sock
```

If required:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## Jenkins AWS Authentication Fails

Run as the Jenkins user:

```bash
sudo -u jenkins aws sts get-caller-identity
```

The expected identity is the Jenkins EC2 IAM role.

Do not add long-lived AWS credentials to the Jenkinsfile as a workaround.

---

## Jenkins ECR Login Works but Push Fails

Authentication and authorization are different.

The IAM role may successfully authenticate but still lack:

```text
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

Verify the repository-scoped IAM policy.

---

## Jenkins Can Access AWS but Not EKS

If:

```bash
aws sts get-caller-identity
```

works but:

```bash
kubectl get nodes
```

returns unauthorized, check the EKS Access Entry and Kubernetes access policy for the Jenkins IAM role.

---

## Jenkins Helm Succeeds but Rollout Fails

Inspect:

```bash
kubectl get pods
```

Then:

```bash
kubectl describe pod <POD_NAME>
```

and:

```bash
kubectl logs <POD_NAME>
```

A successful Helm command does not guarantee a healthy application rollout.

This is why the pipeline runs:

```bash
kubectl rollout status
```

before reporting success.

---

## GitHub Actions Cannot Assume AWS Role

If the workflow reports:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

check:

- AWS OIDC provider
- IAM trust policy
- GitHub repository identity
- Branch restriction
- OIDC `aud` claim
- OIDC `sub` claim
- `id-token: write`

Do not replace OIDC with permanent AWS access keys merely to bypass the error.

---

## GitHub Actions Authenticates but Cannot Push ECR

If:

```bash
aws sts get-caller-identity
```

works but ECR push fails, verify ECR permissions on the GitHub Actions IAM role.

---

## GitHub Actions Pushes ECR but Git Is Not Updated

Check:

```yaml
permissions:
  contents: write
```

Also check:

- Branch protection
- Workflow Git commit step
- `values.yaml` path
- Git push output
- Whether the image tag was already current

---

## Argo Cannot Connect to GitHub

Run:

```bash
argocd repo list
```

Check:

- Deploy key
- Repository URL
- SSH host verification
- Repository permissions

Argo should use a dedicated read-only GitHub credential.

---

## Argo Reports Path Does Not Exist

Check:

```yaml
path: helm/tech-challenge-2
```

The path is relative to the root of the Git repository.

---

## Argo Watches the Wrong Branch

Verify:

```yaml
targetRevision: refs/heads/gitops
```

The Jenkins implementation remains on:

```text
main
```

The Argo implementation should monitor:

```text
gitops
```

---

## Argo Creates Duplicate Kubernetes Resources

Check:

```yaml
helm:
  releaseName: hello-world
```

The chart uses the Helm release name in resource naming.

Using a different release name may cause Argo to render a second set of resources instead of adopting the intended resource names.

---

## Argo Reports OutOfSync

Run:

```bash
argocd app diff tech-challenge-2
```

OutOfSync does not automatically mean something is broken.

It means:

```text
desired Git state
!=
current live state
```

Inspect the actual differences.

---

## Argo Does Not Deploy Automatically

Verify:

```yaml
syncPolicy:
  automated:
    enabled: true
```

Then refresh:

```bash
argocd app get \
  tech-challenge-2 \
  --refresh
```

Argo polls Git periodically, so updates may not appear instantaneously.

---

## Argo Is Synced but Application Is Unhealthy

`Synced` and `Healthy` mean different things.

```text
Synced
→ live configuration matches Git

Healthy
→ Kubernetes resources are functioning
```

Inspect:

```bash
kubectl get pods
kubectl describe pod <POD>
kubectl logs <POD>
```

---


## Actual incident: GitHub webhook failed to connect

**Symptom:** GitHub reported `failed to connect to host` for a ping delivery to the Jenkins `/github-webhook/` endpoint.

**Cause:** The Jenkins EC2 security group allowed TCP/8080 only from the developer's home IP.

**Resolution:** Added GitHub's published IPv4 webhook CIDR ranges to the security group for TCP/8080 while preserving the home-IP rule. GitHub redelivery returned a successful status; a later push to `main` automatically triggered a successful Jenkins build. GitHub's ranges may change; verify them against `https://api.github.com/meta` before reuse. This is a temporary lab workaround, not production-grade HTTP webhook security.

## Actual incident: Argo CD did not initially notice a Git revision

**Symptom:** A prior GitOps test completed GitHub Actions, but Argo CD still displayed the older revision until a hard refresh was invoked.

**Investigation:** The GitOps branch was confirmed as the source of truth, with the image tag committed into the Helm values file. A manual hard refresh made the revision visible on the earlier test.

**Final validation:** A subsequent push was observed without any manual refresh or sync. Argo CD reported `Synced / Healthy` and the ALB served the updated application.

## Actual incident: AWS Load Balancer Controller CrashLoopBackOff

**Symptom:** Controller pods failed during AWS cloud initialization when VPC ID discovery through instance metadata timed out.

**Resolution:** The controller's Helm configuration was updated to specify the VPC ID explicitly, rather than relying on IMDS-based discovery.

## Actual incident: macOS Flask port 5000 conflict

**Symptom:** Local Flask development could not bind port 5000. `lsof -i :5000` showed the macOS Control Center process listening.

**Resolution:** Disabled AirPlay Receiver in macOS System Settings, freeing port 5000.

## Actual incident: EKS managed node group creation failure

**Symptom:** Terraform/EKS reported `CREATE_FAILED`, `NodeCreationFailure`, and unhealthy Kubernetes nodes.

**Investigation:** Reviewed managed node group health, AL2023 `nodeadm` boot output, node IAM permissions, private subnet routing/NAT, cluster endpoint access, and security groups. The historical investigation is recorded; the exact single root-cause correction was not independently confirmed for this README, so it is not asserted. The final cluster supported healthy deployed workloads.

# Infrastructure Teardown

AWS resources in this project incur charges.

Major cost-producing resources may include:

- EKS control plane
- EC2 worker nodes
- NAT Gateway
- Application Load Balancer
- Jenkins EC2 instance
- Public IPv4 addresses
- Data transfer
- ECR storage

Do not leave the lab environment running unnecessarily.

---

# Teardown Order

Because some AWS resources are created dynamically by Kubernetes controllers, delete controller-managed application resources before destroying the VPC.

This is particularly important for the ALB.

## 1. Remove the Argo-managed application if using the GitOps deployment

Disable or delete the Argo Application carefully.

Example:

```bash
kubectl delete application \
  tech-challenge-2 \
  -n argocd
```

Confirm application Kubernetes resources are no longer intended before proceeding.

If the goal is to tear down everything, remove the application resources and wait for controller-created AWS resources to disappear.

---

## 2. Remove Helm Application if Required

For the Jenkins deployment path:

```bash
helm uninstall hello-world
```

Verify:

```bash
kubectl get ingress
kubectl get svc
kubectl get pods
```

---

## 3. Confirm the ALB Has Been Removed

Check:

```bash
kubectl get ingress
```

Then verify in AWS that the application ALB and target groups created by the controller are gone.

Do not immediately destroy the VPC while an ALB is still attached to it.

---

## 4. Remove Cluster Add-ons / Controllers if Needed

Examples:

```text
Argo CD
Cluster Autoscaler
AWS Load Balancer Controller
Metrics Server
```

Depending on how they were installed, remove them through:

```text
Helm
kubectl
EKS add-on management
```

as appropriate.

---

## 5. Remove Jenkins Infrastructure

Stop or terminate the dedicated Jenkins EC2 instance if it is outside Terraform.

Also remove unused:

- Jenkins security group
- Jenkins IAM instance profile
- Jenkins IAM role
- Jenkins-specific EBS volumes if no longer needed

Only remove IAM resources after verifying they are not shared.

---

## 6. Destroy Terraform Infrastructure

Navigate to:

```bash
cd terraform
```

Review:

```bash
terraform plan -destroy
```

Then:

```bash
terraform destroy
```

Review the resources carefully before approving destruction.

Verify afterward that:

- EKS cluster is gone
- Managed node group is gone
- VPC is gone
- NAT Gateway is gone
- Related networking resources are gone

---

## 7. ECR Repository

If ECR was created by Terraform and contains images, deletion may require either repository force deletion configuration or removal of images first.

List:

```bash
aws ecr list-images \
  --repository-name tech-challenge-2-app \
  --region us-east-1
```

Remove images if required before destroying the repository.

---

## 8. Verify the AWS Account

After teardown, manually verify that no challenge-specific resources remain unexpectedly.

Check:

```text
EKS
EC2
Load Balancers
Target Groups
NAT Gateways
Elastic IPs
ECR
IAM roles
CloudFormation stacks created by auxiliary tools
```

The infrastructure is not considered fully cleaned up until chargeable supporting resources are also gone.

---

# Security Notes

This project avoids committing secrets to Git.

Do not commit:

```text
AWS access keys
AWS secret keys
GitHub private keys
Jenkins credentials
Argo private keys
kubeconfig
Terraform state
.env files
```

Jenkins runs on EC2 and uses configured AWS authentication to build and deploy; verify the current credential mechanism in the Jenkins instance before claiming exclusive instance-role authentication.

GitHub Actions uses AWS OIDC.

Argo reads the public GitHub repository; no private deploy key is required.

EKS worker nodes use IAM permissions to pull from ECR.

Each component is given only the access required for its responsibility.

---

# Key Design Decisions

## Manual Before Automation

The deployment was intentionally implemented in layers:

```text
Application
→ Docker
→ Terraform
→ EKS
→ ECR
→ Kubernetes
→ Helm
→ ALB
→ HPA
→ Node Autoscaling
→ Jenkins
→ GitHub Actions
→ Argo CD
```

Each layer was verified before the next automation layer was added.

This reduces troubleshooting complexity and helps isolate failures.

---

## Immutable Image Tags

Both deployment models use Git commit-derived image tags (Jenkins uses a short SHA; GitHub Actions uses a full SHA) rather than relying only on:

```text
latest
```

This provides traceability and prevents ambiguous deployments.

---

## Separate CI/CD Implementations

The Jenkins implementation is maintained on:

```text
main
```

The GitOps implementation is maintained on:

```text
gitops
```

The branches should not be merged during challenge evaluation because they intentionally demonstrate different deployment architectures.

---

## Git as the Source of Truth

In the GitOps implementation, creating a new ECR image does not automatically mean the image should run.

The deployment version is explicitly recorded in:

```text
helm/tech-challenge-2/values.yaml
```

Argo CD then reconciles EKS to match that state.

---

# Final Expected State

The deployed public application was verified to return:

```text
Hello from Tech Challenge 2! It's your host JCloud! GitOps fully automated deployment verified!
```

The verified application ALB endpoint is:

```text
http://k8s-default-hellowor-74c6ecbeec-154059672.us-east-1.elb.amazonaws.com
```

The ALB DNS name can change if infrastructure is recreated.

The repository should contain:

```text
main
→ working Jenkins CI/CD implementation

gitops
→ working GitHub Actions + Argo CD implementation
```

Both workflows should demonstrate a reproducible path from application source code to a containerized application running on Amazon EKS.

---

## Repository and documentation provenance

- Source repository: https://github.com/jhjeremy27-web/Tech-Challenge-2
- `main`: Jenkins-driven deployment; `gitops`: GitHub Actions + Argo CD.
- The original long-form README was preserved as the basis for this revised version. Historical examples are explanatory and should be validated against the currently checked-out branch before executing.
- Infrastructure teardown is destructive and must be reviewed against the active Terraform state before execution.
