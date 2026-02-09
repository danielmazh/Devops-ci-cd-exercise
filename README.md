# DevOps CI/CD Exercise - Complete Infrastructure Automation

[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-red?logo=jenkins)](https://www.jenkins.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-Config-black?logo=ansible)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-Container-blue?logo=docker)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)

> **One command to deploy a complete CI/CD pipeline infrastructure on AWS**

---

## 📋 Table of Contents

- [The Big Picture](#the-big-picture)
- [How It All Works Together](#how-it-all-works-together)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [AWS Cloud Storage](#aws-cloud-storage)
- [Jenkins Pipeline](#jenkins-pipeline)
- [Daily Workflow](#daily-workflow)
- [Commands Reference](#commands-reference)
- [Troubleshooting](#troubleshooting)
- [Cost Management](#cost-management)

---

## 🎯 The Big Picture

This project demonstrates a **complete, production-ready DevOps workflow** where:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           THE BIG PICTURE                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   YOU (Developer)                                                                │
│      │                                                                           │
│      ▼                                                                           │
│   ┌─────────────┐    git push     ┌─────────────┐                               │
│   │   Code      │ ──────────────► │   GitHub    │                               │
│   │   Changes   │                 │   Repo      │                               │
│   └─────────────┘                 └──────┬──────┘                               │
│                                          │                                       │
│                                          │ webhook                               │
│                                          ▼                                       │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         AWS CLOUD                                        │   │
│   │  ┌───────────────────────────────────────────────────────────────────┐  │   │
│   │  │              Parameter Store (FREE - Secure Secrets)              │  │   │
│   │  │  /devops/docker_hub_token  /devops/github_token  /devops/jira_*   │  │   │
│   │  └───────────────────────────────────────────────────────────────────┘  │   │
│   │                                    │                                     │   │
│   │                                    ▼ fetches secrets                     │   │
│   │  ┌─────────────────────┐    ┌─────────────────────┐                     │   │
│   │  │   Jenkins Server    │    │    App Server       │                     │   │
│   │  │   (t3.large)        │    │    (t3.micro)       │                     │   │
│   │  │                     │    │                     │                     │   │
│   │  │  • Run Tests        │    │  • Flask App        │                     │   │
│   │  │  • Build Docker     │───►│  • Docker           │                     │   │
│   │  │  • Push to Hub      │    │  • Health Checks    │                     │   │
│   │  │  • Deploy App       │    │                     │                     │   │
│   │  └─────────────────────┘    └─────────────────────┘                     │   │
│   │            │                                                             │   │
│   │            │ pushes image                                                │   │
│   │            ▼                                                             │   │
│   │  ┌─────────────────────┐    ┌─────────────────────┐                     │   │
│   │  │   S3 Bucket         │    │   DynamoDB Table    │                     │   │
│   │  │   (Terraform State) │    │   (State Locking)   │                     │   │
│   │  └─────────────────────┘    └─────────────────────┘                     │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                          │                                       │
│                                          ▼                                       │
│   ┌─────────────┐                 ┌─────────────┐                               │
│   │ Docker Hub  │                 │    JIRA     │ ◄── Creates issues on failure │
│   │ (Registry)  │                 │  (Tracking) │                               │
│   └─────────────┘                 └─────────────┘                               │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 How It All Works Together

### 1️⃣ Infrastructure Provisioning (Terraform)
```
terraform.tfvars ──► Terraform ──► Creates AWS Resources
                                   • VPC, Subnets, IGW
                                   • Security Groups
                                   • EC2 Instances (Jenkins + App)
                                   • Elastic IPs
                                   • IAM Roles
```

### 2️⃣ Server Configuration (Ansible)
```
Ansible Playbooks ──► SSH to EC2 ──► Configures Servers
                                     • Installs Docker & Docker Compose
                                     • Starts Jenkins container
                                     • Installs all Jenkins plugins automatically
                                     • Installs Firefox + GeckoDriver (E2E tests)
                                     • Sets up credentials
                                     • Creates pipeline job
```

### 3️⃣ CI/CD Pipeline (Jenkins)
```
Code Push ──► Jenkins Pipeline ──► Automated Workflow (10 Stages)
                                   • Checkout code
                                   • Setup Python environment
                                   • Run unit tests (pytest + coverage)
                                   • Run integration tests
                                   • Security scan (Bandit)
                                   • E2E tests (Selenium + Firefox headless)
                                   • Performance tests (Locust)
                                   • Build Docker image
                                   • Push to Docker Hub
                                   • Deploy to staging/production (optional)
```

### 4️⃣ Secrets Management (AWS Parameter Store)
```
Parameter Store (FREE) ──► Securely Stores ──► All Credentials
                                               • Docker Hub token
                                               • GitHub token
                                               • JIRA API token
                                               • Jenkins password
                                               • SSH key path
```

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
│  │  │  │ 2 vCPU, 8GB RAM │   │  │  │ 2 vCPU, 1GB RAM │   │           │   │
│  │  │  │                 │   │  │  │                 │   │           │   │
│  │  │  │ • Jenkins       │   │  │  │ • Docker        │   │           │   │
│  │  │  │ • Docker        │   │  │  │ • Flask App     │   │           │   │
│  │  │  │ • Python        │   │  │  │                 │   │           │   │
│  │  │  └────────┬────────┘   │  │  └────────┬────────┘   │           │   │
│  │  │           │ EIP        │  │           │ EIP        │           │   │
│  │  └───────────┼────────────┘  └───────────┼────────────┘           │   │
│  │              │                           │                         │   │
│  │  ┌───────────┴───────────────────────────┴───────────────────┐    │   │
│  │  │                    Internet Gateway                        │    │   │
│  │  └───────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PERSISTENT STORAGE (stays after destroy)          │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │   │
│  │  │ Parameter Store  │  │   S3 Bucket      │  │  DynamoDB Table  │  │   │
│  │  │ (Secrets - FREE) │  │ (TF State ~$0)   │  │ (Lock - FREE)    │  │   │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 AWS Cloud Storage

All credentials are stored securely in **AWS Parameter Store** (FREE tier):

### Stored Secrets (16 parameters)

| Parameter | Type | Description |
|-----------|------|-------------|
| `/devops/docker_hub_username` | String | Docker Hub username |
| `/devops/docker_hub_token` | 🔐 SecureString | Docker Hub access token |
| `/devops/github_username` | String | GitHub username |
| `/devops/github_token` | 🔐 SecureString | GitHub personal access token |
| `/devops/github_repo` | String | Repository name |
| `/devops/jira_url` | String | JIRA base URL |
| `/devops/jira_email` | String | JIRA email |
| `/devops/jira_api_token` | 🔐 SecureString | JIRA API token |
| `/devops/jira_project_key` | String | JIRA project key |
| `/devops/jenkins_admin_user` | String | Jenkins admin username |
| `/devops/jenkins_password` | 🔐 SecureString | Jenkins admin password |
| `/devops/aws_region` | String | AWS region |
| `/devops/aws_account_id` | String | AWS account ID |
| `/devops/ssh_key_path` | String | Local SSH key path |
| `/devops/ssh_key_name` | String | AWS key pair name |
| `/devops/notification_email` | String | Email for notifications |

### Storage Resources

| Resource | Name | Purpose | Cost |
|----------|------|---------|------|
| **S3 Bucket** | `devops-tfstate-632008729195` | Terraform state | ~$0.001/month |
| **DynamoDB** | `devops-tfstate-lock` | State locking | FREE |
| **Parameter Store** | `/devops/*` | Secrets | FREE |

---

## 📦 Prerequisites

### Required Software

```bash
# Check all prerequisites
terraform version    # >= 1.0.0
ansible --version    # >= 2.9
aws --version        # >= 2.0
jq --version         # >= 1.6
```

### Required Files

| File | Location | Purpose |
|------|----------|---------|
| SSH Key | `/Users/danielmazmazhbits/keys/devops-key-private-account.pem` | EC2 access |
| Terraform vars | `infrastructure/terraform/terraform.tfvars` | AWS credentials |

---

## 🚀 Quick Start

### First Time Setup (One-time only)

```bash
# 1. Clone the repository
git clone https://github.com/danielmazh/devops-ci-cd-exercise.git
cd devops-ci-cd-exercise

# 2. Set up AWS cloud storage (creates S3, DynamoDB, Parameter Store)
./scripts/setup-aws-storage.sh

# 3. Initialize Terraform with S3 backend
cd infrastructure/terraform
terraform init -migrate-state
cd ../..
```

### Deploy Infrastructure

```bash
# Single command to deploy everything
./scripts/bootstrap-infrastructure.sh
```

**Expected time: ~10-15 minutes**

**What happens during deployment:**
1. ✅ Validates prerequisites (terraform, ansible, aws cli)
2. ✅ Loads credentials from Parameter Store
3. ✅ Provisions EC2 instances via Terraform
4. ✅ Configures servers via Ansible (Docker, Jenkins)
5. ✅ Installs 30+ Jenkins plugins automatically
6. ✅ Installs Firefox + GeckoDriver for E2E tests
7. ✅ Creates and loads the pipeline job
8. ✅ Performs health checks

### Access Services

After deployment:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jenkins** | `http://<JENKINS_IP>:8080` | admin / DevOps2026! |
| **App** | `http://<APP_IP>` | N/A |
| **Pipeline** | `devops-testing-app` job | Pre-configured |

---

## 🔄 Jenkins Pipeline

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    JENKINS PIPELINE FLOW (10 Stages)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                           │
│  │    START     │                                                           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Create Python venv, install dependencies                │
│  │    Setup     │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   pytest with coverage (MANDATORY - must pass)            │
│  │  Unit Tests  │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   API tests (MANDATORY - must pass)                       │
│  │ Integration  │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Bandit security scanner                                 │
│  │Security Scan │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Selenium + Firefox headless (9 tests)                   │
│  │  E2E Tests   │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Locust load testing (10 users, 30s)                     │
│  │ Performance  │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Multi-stage Docker build                                │
│  │ Docker Build │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Push to Docker Hub (danielmazh/devops-testing-app)      │
│  │  Push Image  │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐   Deploy via SSH (optional, requires params)              │
│  │   Deploy     │──────────────────────────────────────────────►           │
│  └──────┬───────┘                                                           │
│         ▼                                                                    │
│  ┌──────────────┐                                                           │
│  │   SUCCESS    │   ◄── Email notification + workspace cleanup              │
│  └──────────────┘                                                           │
│                                                                              │
│  On FAILURE: ──► Create JIRA issue + Email notification                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Test Reports

Jenkins displays:
- ✅ Unit test results (JUnit)
- ✅ Code coverage report (HTML)
- ✅ Integration test report (HTML)
- ✅ E2E test report (HTML)
- ✅ Performance test report (HTML)
- ✅ Archived artifacts

### Automatically Installed Components

The deployment automatically installs all required components:

**Jenkins Plugins (30+):**
| Category | Plugins |
|----------|---------|
| Pipeline Core | workflow-job, workflow-cps, workflow-aggregator, pipeline-model-definition |
| SCM | scm-api, workflow-scm-step, git, git-client, github |
| Build Tools | timestamper, ansicolor, pipeline-utility-steps |
| Testing | junit, htmlpublisher |
| Post-Build | ws-cleanup, email-ext |
| Credentials | credentials-binding, ssh-agent, ssh-credentials |
| Configuration | configuration-as-code, job-dsl |

**E2E Testing Tools (inside Jenkins container):**
| Tool | Version | Purpose |
|------|---------|---------|
| Firefox ESR | Latest | Headless browser for Selenium |
| GeckoDriver | 0.34.0 | WebDriver for Firefox |
| Xvfb | Latest | Virtual display for headless mode |
| Python 3 | Latest | Test runner |

---

## 📅 Daily Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                     RECOMMENDED WORKFLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🌅 START OF DAY (or study session)                             │
│     │                                                            │
│     └──► ./scripts/bootstrap-infrastructure.sh                   │
│          • Fetches credentials from Parameter Store              │
│          • Creates EC2 instances                                 │
│          • Configures Jenkins                                    │
│          • ~10-15 minutes                                        │
│                                                                  │
│  💻 DURING THE DAY                                              │
│     │                                                            │
│     └──► Work on exercises                                       │
│          • Push code to GitHub                                   │
│          • Jenkins runs pipeline automatically                   │
│          • View results at http://<JENKINS_IP>:8080              │
│                                                                  │
│  🌙 END OF DAY (save money!)                                    │
│     │                                                            │
│     └──► ./scripts/destroy-infrastructure.sh                     │
│          • Choose [K] to KEEP storage                            │
│          • Destroys EC2 instances only                           │
│          • Credentials stay in Parameter Store                   │
│          • State saved in S3                                     │
│                                                                  │
│  🎓 END OF COURSE (zero cost)                                   │
│     │                                                            │
│     └──► ./scripts/destroy-infrastructure.sh --delete-storage    │
│          • Type 'DELETE ALL' to confirm                          │
│          • Deletes EVERYTHING including storage                  │
│          • $0.00/month ongoing cost                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎮 Commands Reference

### Infrastructure Commands

| Command | Description |
|---------|-------------|
| `./scripts/bootstrap-infrastructure.sh` | Deploy everything |
| `./scripts/bootstrap-infrastructure.sh --dry-run` | Preview without changes |
| `./scripts/bootstrap-infrastructure.sh --skip-terraform` | Only run Ansible |
| `./scripts/destroy-infrastructure.sh` | Destroy infra (keep storage) |
| `./scripts/destroy-infrastructure.sh --delete-storage` | Destroy EVERYTHING |
| `./scripts/setup-aws-storage.sh` | Set up S3/DynamoDB/Params |

### AWS Commands (Verification)

```bash
# List all stored parameters
aws ssm describe-parameters --query 'Parameters[?starts_with(Name, `/devops/`)].Name'

# Get a specific parameter
aws ssm get-parameter --name "/devops/docker_hub_username" --query 'Parameter.Value'

# Get encrypted parameter
aws ssm get-parameter --name "/devops/docker_hub_token" --with-decryption --query 'Parameter.Value'

# List S3 buckets
aws s3 ls | grep devops

# Check DynamoDB table
aws dynamodb describe-table --table-name devops-tfstate-lock
```

### SSH Commands

```bash
# Connect to Jenkins server
ssh -i /Users/danielmazmazhbits/keys/devops-key-private-account.pem ec2-user@<JENKINS_IP>

# Connect to App server
ssh -i /Users/danielmazmazhbits/keys/devops-key-private-account.pem ec2-user@<APP_IP>

# View Jenkins logs
ssh -i <KEY> ec2-user@<JENKINS_IP> "docker logs jenkins"
```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "AWS credentials not configured" | Check `terraform.tfvars` has correct keys |
| "SSH key not found" | Verify path: `/Users/.../keys/devops-key-private-account.pem` |
| "Jenkins not accessible" | Wait 2-3 minutes after deployment, check security group |
| "Pipeline fails at Docker push" | Verify Docker Hub token in Parameter Store |
| "Terraform state lock" | Run `terraform force-unlock <LOCK_ID>` |
| "No such DSL method" (plugin error) | Plugins install automatically; restart Jenkins if needed |
| "curl package conflict" on Amazon Linux | Already fixed - curl-minimal is used instead |
| "E2E tests fail - Firefox not found" | Firefox is auto-installed in Jenkins container |
| "Pipeline job not loading" | Plugins install on first boot; job loads after restart |

### Debug Commands

```bash
# Check Jenkins container
ssh -i <KEY> ec2-user@<JENKINS_IP> "docker ps && docker logs jenkins --tail 50"

# Check Ansible logs
cat /tmp/ansible-jenkins.log

# Verify AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-testing-app"
```

---

## 💰 Cost Management

### Cost Breakdown

| State | Resources | Monthly Cost |
|-------|-----------|--------------|
| **Running** | EC2 (Jenkins t3.large + App t3.micro) + EIP + Storage | ~$70-80/month |
| **Stopped** | Only persistent storage | ~$0.001/month |
| **Deleted** | Nothing | $0.00/month |

### Cost Optimization Tips

1. **Destroy at end of each day** - Only pay for hours used
2. **Use `--delete-storage` at end of course** - Zero ongoing costs
3. **t3.large is recommended** - Faster builds save time

### Verify Zero Cost

After `--delete-storage`:

```bash
# Should return empty results
aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-testing-app"
aws s3 ls | grep devops-tfstate
aws ssm describe-parameters --query 'Parameters[?starts_with(Name, `/devops/`)]'
aws dynamodb list-tables | grep devops
```

---

## 📁 Project Structure

```
devops-ci-cd-exercise/
├── app/                          # Flask application
│   ├── __init__.py              # App factory
│   └── routes/                  # API endpoints
├── docker/                       # Docker configurations
│   └── Dockerfile               # Multi-stage build
├── infrastructure/
│   ├── terraform/               # Infrastructure as Code
│   │   ├── main.tf             # Provider config
│   │   ├── backend.tf          # S3 backend (auto-generated)
│   │   ├── terraform.tfvars    # Your credentials (gitignored)
│   │   └── *.tf                # Resource definitions
│   └── ansible/                 # Configuration management
│       ├── playbooks/          # Setup playbooks
│       └── roles/              # Ansible roles
├── jenkins/
│   └── Jenkinsfile             # Pipeline definition
├── scripts/
│   ├── bootstrap-infrastructure.sh   # Deploy everything
│   ├── destroy-infrastructure.sh     # Cleanup everything
│   └── setup-aws-storage.sh         # Setup cloud storage
├── tests/
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   └── e2e/                    # End-to-end tests
└── README.md                   # This file
```

---

## ✅ Checklist

### Initial Setup (One-time)
- [x] AWS account with IAM user
- [x] SSH key pair created in AWS
- [x] `terraform.tfvars` configured
- [x] Cloud storage set up (`setup-aws-storage.sh`)
- [x] Terraform initialized with S3 backend

### Each Deployment
- [ ] Run `./scripts/bootstrap-infrastructure.sh`
- [ ] Access Jenkins at `http://<IP>:8080`
- [ ] Run the pipeline
- [ ] Run `./scripts/destroy-infrastructure.sh` when done

### End of Course
- [ ] Run `./scripts/destroy-infrastructure.sh --delete-storage`
- [ ] Verify zero resources remain
- [ ] Rotate/delete AWS access keys

---

## 📧 Contact

- **Author:** Daniel Mazhbits
- **Email:** daniel.mazhbits@gmail.com
- **GitHub:** [@danielmazh](https://github.com/danielmazh)

---

<div align="center">

**Built for DevOps Training - Lesson 47**

🚀 **One command. Complete CI/CD. Production ready.** 🚀

</div>
