# DevOps CI/CD Exercise - Complete Infrastructure Automation

[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-red?logo=jenkins)](https://www.jenkins.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-Config-black?logo=ansible)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-Container-blue?logo=docker)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)

> **One command to deploy a complete CI/CD pipeline infrastructure on AWS**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [Infrastructure Components](#infrastructure-components)
- [Jenkins Pipeline](#jenkins-pipeline)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Contributing](#contributing)

---

## 🎯 Overview

This project provides a **fully automated, production-ready CI/CD infrastructure** that can be deployed to AWS with a single command. It includes:

- **Jenkins** - CI/CD automation server with pre-configured pipeline
- **Docker** - Containerized application and build environment
- **Terraform** - Infrastructure as Code for AWS resources
- **Ansible** - Configuration management and server provisioning
- **Flask Application** - Sample Python web application with tests

### Key Features

✅ **One-Command Deployment** - Deploy entire infrastructure with `./scripts/bootstrap-infrastructure.sh`  
✅ **Complete CI/CD Pipeline** - Unit tests, integration tests, code quality, Docker build & push  
✅ **Infrastructure as Code** - All infrastructure defined in Terraform  
✅ **Configuration Management** - Server configuration automated with Ansible  
✅ **Security Best Practices** - Proper IAM roles, security groups, and credential management  
✅ **Full Cleanup** - Destroy everything with `./scripts/destroy-infrastructure.sh`  

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        VPC (10.0.0.0/16)                             │   │
│  │  ┌─────────────────────────┐  ┌─────────────────────────┐           │   │
│  │  │   Public Subnet 1       │  │   Public Subnet 2       │           │   │
│  │  │   10.0.1.0/24          │  │   10.0.2.0/24          │           │   │
│  │  │                         │  │                         │           │   │
│  │  │  ┌─────────────────┐   │  │  ┌─────────────────┐   │           │   │
│  │  │  │ Jenkins Server  │   │  │  │   App Server    │   │           │   │
│  │  │  │ (t3.large)      │   │  │  │   (t3.micro)    │   │           │   │
│  │  │  │                 │   │  │  │                 │   │           │   │
│  │  │  │ - Jenkins       │   │  │  │ - Docker        │   │           │   │
│  │  │  │ - Docker        │   │  │  │ - Flask App     │   │           │   │
│  │  │  │ - Ansible       │   │  │  │                 │   │           │   │
│  │  │  │ - AWS CLI       │   │  │  │                 │   │           │   │
│  │  │  └─────────────────┘   │  │  └─────────────────┘   │           │   │
│  │  │         ↓ EIP          │  │         ↓ EIP          │           │   │
│  │  └─────────────────────────┘  └─────────────────────────┘           │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    Internet Gateway                          │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           External Services                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  GitHub     │  │ Docker Hub  │  │    JIRA     │  │   Email     │        │
│  │  (Source)   │  │  (Registry) │  │  (Issues)   │  │(Notifications)│       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### Required Software

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.0.0 | [Install Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| Ansible | >= 2.9 | `pip install ansible` or `brew install ansible` |
| AWS CLI | >= 2.0 | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| jq | >= 1.6 | `brew install jq` or `apt install jq` |
| nc (netcat) | - | Usually pre-installed on macOS/Linux |

### Required Accounts & Credentials

| Service | What You Need | How to Get It |
|---------|---------------|---------------|
| **AWS** | Access Key ID + Secret Key | [IAM Console](https://console.aws.amazon.com/iam/) → Users → Security Credentials |
| **Docker Hub** | Personal Access Token | [Docker Hub](https://hub.docker.com/settings/security) → New Access Token |
| **GitHub** | Personal Access Token (optional) | [GitHub Tokens](https://github.com/settings/tokens) → Generate new token |
| **JIRA** | API Token (optional) | [Atlassian API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens) |

### AWS Permissions Required

The AWS IAM user needs the following permissions:
- `EC2FullAccess`
- `VPCFullAccess`
- `IAMFullAccess` (for instance profiles)
- Or use `AdministratorAccess` for simplicity

### SSH Key Pair

You need an AWS EC2 key pair:

```bash
# Option 1: Create via AWS Console
# Go to EC2 → Key Pairs → Create Key Pair → Download .pem file

# Option 2: Import existing key
aws ec2 import-key-pair \
    --key-name "your-key-name" \
    --public-key-material fileb://~/.ssh/id_rsa.pub
```

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/danielmazh/devops-ci-cd-exercise.git
cd devops-ci-cd-exercise
```

### 2. Configure Credentials

Edit `infrastructure/terraform/terraform.tfvars`:

```hcl
# AWS Credentials
aws_region     = "us-east-1"
aws_access_key = "YOUR_AWS_ACCESS_KEY"
aws_secret_key = "YOUR_AWS_SECRET_KEY"

# SSH Key
key_name             = "your-key-name"
ssh_private_key_path = "/path/to/your/key.pem"

# Docker Hub
docker_hub_username = "your-docker-username"
docker_hub_token    = "dckr_pat_xxxxx"

# GitHub (optional)
github_username = "your-github-username"
github_token    = "ghp_xxxxx"

# JIRA (optional)
jira_url       = "https://your-domain.atlassian.net"
jira_email     = "your-email@example.com"
jira_api_token = "your-jira-token"
```

### 3. Deploy Everything

```bash
./scripts/bootstrap-infrastructure.sh
```

**Expected Output:**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    DevOps CI/CD Infrastructure Bootstrap                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

[SUCCESS] All prerequisites met!
[INFO] Running Terraform...
[INFO] Applying infrastructure (this may take 3-5 minutes)...
[SUCCESS] Jenkins IP: 34.xxx.xxx.xxx
[SUCCESS] App IP: 3.xxx.xxx.xxx
[INFO] Running Ansible Configuration...
[SUCCESS] Jenkins setup completed
[SUCCESS] App setup completed
[SUCCESS] Jenkins is accessible at http://34.xxx.xxx.xxx:8080

╔══════════════════════════════════════════════════════════════════════════════╗
║                         🎉 DEPLOYMENT COMPLETE! 🎉                            ║
╚══════════════════════════════════════════════════════════════════════════════╝

  📍 Jenkins URL:     http://34.xxx.xxx.xxx:8080
  📍 App URL:         http://3.xxx.xxx.xxx
  
  🔑 Jenkins Credentials:
     Username: admin
     Password: DevOps2026!
```

### 4. Access Jenkins

1. Open `http://<JENKINS_IP>:8080` in your browser
2. Login with:
   - **Username:** `admin`
   - **Password:** `DevOps2026!`
3. Navigate to the `devops-testing-app` pipeline job
4. Click **"Build Now"** to run the pipeline

---

## 📖 Detailed Setup Guide

### Step 1: Verify Prerequisites

```bash
# Check all required tools are installed
terraform version
ansible --version
aws --version
jq --version

# Verify AWS credentials
aws sts get-caller-identity
```

### Step 2: Configure terraform.tfvars

Create or edit `infrastructure/terraform/terraform.tfvars`:

```hcl
# =============================================================================
# AWS Configuration
# =============================================================================
aws_region     = "us-east-1"
aws_access_key = "AKIAXXXXXXXXXXXXXXXX"
aws_secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# =============================================================================
# Project Configuration
# =============================================================================
project_name = "devops-testing-app"
environment  = "staging"
owner_email  = "your-email@example.com"

# =============================================================================
# EC2 Configuration
# =============================================================================
jenkins_instance_type = "t3.large"     # 2 vCPU, 8GB RAM (recommended)
jenkins_volume_size   = 30

app_instance_type = "t3.micro"         # 2 vCPU, 1GB RAM
app_volume_size   = 30

# SSH Key (MUST exist in AWS)
key_name             = "your-key-name"
ssh_private_key_path = "/path/to/your/key.pem"

# =============================================================================
# Docker Hub Credentials
# =============================================================================
docker_hub_username = "your-dockerhub-username"
docker_hub_token    = "dckr_pat_xxxxxxxxxxxxxxxxxxxxxxxxx"
docker_image_name   = "devops-testing-app"

# =============================================================================
# GitHub Configuration (optional - for private repos)
# =============================================================================
github_username = "your-github-username"
github_token    = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxx"
github_repo     = "devops-ci-cd-exercise"

# =============================================================================
# JIRA Configuration (optional - for issue tracking)
# =============================================================================
jira_url         = "https://your-domain.atlassian.net"
jira_email       = "your-email@example.com"
jira_api_token   = "your-jira-api-token"
jira_project_key = "CICD"

# =============================================================================
# Jenkins Configuration
# =============================================================================
jenkins_admin_user     = "admin"
jenkins_admin_password = "DevOps2026!"
```

### Step 3: Deploy Infrastructure

```bash
# Full deployment (Terraform + Ansible)
./scripts/bootstrap-infrastructure.sh

# Preview what will be created (dry-run)
./scripts/bootstrap-infrastructure.sh --dry-run

# Skip Terraform (only run Ansible on existing infra)
./scripts/bootstrap-infrastructure.sh --skip-terraform

# Skip Ansible (only create AWS resources)
./scripts/bootstrap-infrastructure.sh --skip-ansible
```

### Step 4: Run the Pipeline

1. Access Jenkins at `http://<JENKINS_IP>:8080`
2. Login with your credentials
3. Click on `devops-testing-app` job
4. Click **"Build with Parameters"**
5. Optionally enable:
   - `RUN_PERFORMANCE_TESTS` - Run Locust performance tests
   - `DEPLOY_TO_STAGING` - Deploy to staging server
   - `DEPLOY_TO_PRODUCTION` - Deploy to production (requires approval)
6. Click **"Build"**

---

## 🔧 Infrastructure Components

### AWS Resources Created

| Resource | Count | Description |
|----------|-------|-------------|
| VPC | 1 | Virtual Private Cloud (10.0.0.0/16) |
| Subnets | 2 | Public subnets in different AZs |
| Internet Gateway | 1 | Internet access for public subnets |
| Route Tables | 1 | Public route table with IGW |
| Security Groups | 2 | Jenkins SG + App SG |
| EC2 Instances | 2 | Jenkins server + App server |
| Elastic IPs | 2 | Static IPs for both servers |
| IAM Roles | 2 | Instance profiles for EC2 |
| VPC Endpoint | 1 | S3 endpoint for private access |

### Security Groups

**Jenkins Security Group:**
- Port 22 (SSH) - Your IP only
- Port 8080 (Jenkins UI) - Anywhere
- Port 50000 (Jenkins Agent) - VPC only

**App Security Group:**
- Port 22 (SSH) - Your IP only
- Port 80 (HTTP) - Anywhere
- Port 5000 (Flask) - VPC only

---

## 🔄 Jenkins Pipeline

### Pipeline Stages

```
┌──────────────────┐
│ Setup Environment│ → Create Python venv, install dependencies
└────────┬─────────┘
         ▼
┌──────────────────┐
│   Code Quality   │ → Flake8, Pylint, Bandit (parallel)
└────────┬─────────┘
         ▼
┌──────────────────┐
│   Unit Tests     │ → pytest with coverage (MANDATORY)
└────────┬─────────┘
         ▼
┌──────────────────┐
│Integration Tests │ → API tests with Flask client (MANDATORY)
└────────┬─────────┘
         ▼
┌──────────────────┐
│    E2E Tests     │ → Selenium tests (SKIPPED in CI)
└────────┬─────────┘
         ▼
┌──────────────────┐
│Performance Tests │ → Locust load tests (OPTIONAL)
└────────┬─────────┘
         ▼
┌──────────────────┐
│Build Docker Image│ → Multi-stage Docker build
└────────┬─────────┘
         ▼
┌──────────────────┐
│Push to Docker Hub│ → Push tagged image to registry
└────────┬─────────┘
         ▼
┌──────────────────┐
│Deploy to Staging │ → Ansible deployment (OPTIONAL)
└────────┬─────────┘
         ▼
┌──────────────────┐
│Deploy to Prod    │ → Manual approval + deployment (OPTIONAL)
└──────────────────┘
```

### Pipeline Features

- **Parallel Execution** - Code quality checks run in parallel
- **Test Reports** - JUnit XML + HTML reports published to Jenkins
- **Code Coverage** - Coverage reports with threshold enforcement
- **Docker Build** - Multi-stage builds with build args
- **Artifact Management** - All reports archived
- **Failure Handling** - JIRA issue creation + email notifications

---

## ⚙️ Configuration

### Environment Variables

You can use environment variables instead of `terraform.tfvars`:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export DOCKER_HUB_TOKEN="your-docker-token"
export GITHUB_TOKEN="your-github-token"
export SSH_KEY_PATH="/path/to/your/key.pem"
```

### Jenkins Configuration as Code (CasC)

Jenkins is configured automatically using CasC at:
- `infrastructure/ansible/roles/jenkins/templates/jenkins-casc.yaml.j2`

### Ansible Inventory

Auto-generated at:
- `infrastructure/ansible/inventory/staging.ini`

---

## 🐛 Troubleshooting

### Common Issues

#### 1. "AWS credentials not configured"

```bash
# Verify credentials
aws sts get-caller-identity

# Check terraform.tfvars has correct values
cat infrastructure/terraform/terraform.tfvars | grep aws_
```

#### 2. "SSH key not found"

```bash
# Verify key exists
ls -la /path/to/your/key.pem

# Verify key permissions
chmod 400 /path/to/your/key.pem
```

#### 3. "Jenkins not accessible after deployment"

```bash
# SSH into Jenkins server
ssh -i /path/to/key.pem ec2-user@<JENKINS_IP>

# Check Jenkins container
docker ps
docker logs jenkins

# Check if Jenkins is listening
curl http://localhost:8080/login
```

#### 4. "Docker permission denied in Jenkins"

```bash
# SSH into Jenkins server
ssh -i /path/to/key.pem ec2-user@<JENKINS_IP>

# Fix docker socket permissions
docker exec -u root jenkins bash -c "chmod 666 /var/run/docker.sock"
```

#### 5. "Terraform state lock"

```bash
# Force unlock (use with caution)
cd infrastructure/terraform
terraform force-unlock <LOCK_ID>
```

### Viewing Logs

```bash
# Bootstrap script logs
cat /tmp/ansible-jenkins.log
cat /tmp/ansible-app.log

# Jenkins container logs
ssh -i /path/to/key.pem ec2-user@<JENKINS_IP> "docker logs jenkins"

# Terraform debug
TF_LOG=DEBUG terraform apply
```

---

## 🗑️ Cleanup

### Destroy All Resources

```bash
# Complete destruction with confirmation
./scripts/destroy-infrastructure.sh

# Force destroy (no confirmation)
./scripts/destroy-infrastructure.sh --force

# Destroy + cleanup orphaned resources
./scripts/destroy-infrastructure.sh --cleanup

# Preview what will be destroyed
./scripts/destroy-infrastructure.sh --dry-run
```

### Manual Verification

```bash
# Verify no resources remain
aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=devops-testing-app" \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}'

aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=devops-testing-app"
```

---

## 📁 Project Structure

```
devops-ci-cd-exercise/
├── app/                          # Flask application
│   ├── __init__.py              # App factory
│   └── routes/                  # API endpoints
├── docker/                       # Docker configurations
│   ├── Dockerfile               # Multi-stage app Dockerfile
│   └── docker-compose.yml       # Local development
├── infrastructure/
│   ├── terraform/               # Infrastructure as Code
│   │   ├── main.tf             # Provider configuration
│   │   ├── variables.tf        # Variable definitions
│   │   ├── terraform.tfvars    # Variable values (SENSITIVE)
│   │   ├── vpc.tf              # VPC resources
│   │   ├── security_groups.tf  # Security groups
│   │   ├── jenkins.tf          # Jenkins EC2 instance
│   │   ├── app.tf              # App EC2 instance
│   │   ├── iam.tf              # IAM roles & policies
│   │   └── outputs.tf          # Output values
│   └── ansible/                 # Configuration management
│       ├── ansible.cfg         # Ansible configuration
│       ├── inventory/          # Host inventories
│       ├── playbooks/          # Ansible playbooks
│       │   ├── jenkins-setup.yml
│       │   ├── app-setup.yml
│       │   └── deploy-app.yml
│       ├── roles/              # Ansible roles
│       │   ├── jenkins/
│       │   └── docker-app/
│       └── group_vars/         # Group variables
├── jenkins/
│   ├── Jenkinsfile             # Main pipeline definition
│   └── plugins.txt             # Required plugins
├── scripts/
│   ├── bootstrap-infrastructure.sh   # Deploy everything
│   ├── destroy-infrastructure.sh     # Cleanup everything
│   ├── build-and-push.sh            # Build & push Docker
│   └── health-check.sh              # Health verification
├── tests/
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   ├── e2e/                    # End-to-end tests
│   └── performance/            # Performance tests
├── requirements.txt            # Python dependencies
├── pytest.ini                 # Pytest configuration
├── env.template               # Environment template
└── README.md                  # This file
```

---

## 🔐 Security Notes

1. **Never commit** `terraform.tfvars` or `.env` files
2. **Rotate credentials** after testing
3. **Restrict SSH access** to your IP only in production
4. **Use IAM roles** instead of access keys in production
5. **Enable S3 versioning** for Terraform state in production

---

## 📊 Cost Estimation

| Resource | Type | Monthly Cost (us-east-1) |
|----------|------|-------------------------|
| Jenkins EC2 | t3.large | ~$60 |
| App EC2 | t3.micro | ~$8 |
| Elastic IPs | 2x | ~$7 (when not attached) |
| EBS Volumes | 60GB total | ~$6 |
| **Total** | | **~$75-80/month** |

> 💡 **Tip:** Destroy infrastructure when not in use to save costs!

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is for educational purposes as part of DevOps training.

---

## 📧 Contact

- **Author:** Daniel Mazhbits
- **Email:** daniel.mazhbits@gmail.com
- **GitHub:** [@danielmazh](https://github.com/danielmazh)

---

<div align="center">

**⭐ Star this repo if you found it helpful! ⭐**

</div>
