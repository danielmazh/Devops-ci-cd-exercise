# DevOps CI/CD Complete Infrastructure Guide

## Comprehensive Technical Presentation

---

# Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Architecture Deep Dive](#2-architecture-deep-dive)
3. [Infrastructure as Code (Terraform)](#3-infrastructure-as-code-terraform)
4. [Configuration Management (Ansible)](#4-configuration-management-ansible)
5. [CI/CD Pipeline (Jenkins)](#5-cicd-pipeline-jenkins)
6. [Testing Strategy](#6-testing-strategy)
7. [Security & Secrets Management](#7-security--secrets-management)
8. [Cost Management & Optimization](#8-cost-management--optimization)
9. [Operations & Troubleshooting](#9-operations--troubleshooting)
10. [Deployment Workflow](#10-deployment-workflow)
11. [Project Structure - Complete File Tree](#11-project-structure---complete-file-tree)

---

# 1. Executive Overview

## 1.1 What This Project Demonstrates

This project is a **production-ready, enterprise-grade CI/CD infrastructure** that showcases modern DevOps best practices:

| Concept | Implementation | Industry Standard |
|---------|----------------|-------------------|
| **Infrastructure as Code** | Terraform | HashiCorp standard |
| **Configuration Management** | Ansible | Red Hat ecosystem |
| **Continuous Integration** | Jenkins Pipeline | Most popular CI tool |
| **Containerization** | Docker + Docker Compose | Container standard |
| **Cloud Platform** | AWS (EC2, VPC, IAM, S3) | Market leader |
| **Secrets Management** | AWS Parameter Store | Cloud-native security |
| **State Management** | S3 + DynamoDB locking | Terraform best practice |

## 1.2 The "Single Command" Philosophy

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│    ./scripts/bootstrap-infrastructure.sh                             │
│                                                                      │
│    This single command:                                              │
│    ✅ Provisions 22+ AWS resources                                   │
│    ✅ Configures 2 EC2 servers                                       │
│    ✅ Installs 30+ Jenkins plugins                                   │
│    ✅ Sets up E2E testing tools (Firefox, Selenium)                  │
│    ✅ Creates ready-to-run CI/CD pipeline                            │
│    ✅ Configures all credentials securely                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 1.3 Key Differentiators

| Feature | Traditional Approach | This Project |
|---------|---------------------|--------------|
| Setup Time | Days/weeks of manual config | **10-15 minutes automated** |
| Reproducibility | "Works on my machine" | **Identical every time** |
| Security | Manual credential handling | **AWS-managed secrets** |
| Cost Control | Always-on resources | **Destroy/recreate on demand** |
| Testing | Manual or partial | **Full pyramid automated** |

---

# 2. Architecture Deep Dive

## 2.1 High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              THE COMPLETE PICTURE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   DEVELOPER MACHINE                         EXTERNAL SERVICES                    │
│   ┌─────────────────┐                      ┌─────────────────┐                  │
│   │ Local IDE       │     git push         │   GitHub        │                  │
│   │ Code Changes    │─────────────────────►│   Repository    │                  │
│   │                 │                      │                 │                  │
│   │ terraform.tfvars│──┐                   └────────┬────────┘                  │
│   └─────────────────┘  │                            │ webhook                    │
│                        │                            ▼                            │
│   ┌─────────────────┐  │   ┌────────────────────────────────────────────────┐   │
│   │ Scripts         │  │   │                    AWS CLOUD                    │   │
│   │ • bootstrap     │  │   │  ┌────────────────────────────────────────────┐ │   │
│   │ • destroy       │──┼──►│  │              VPC (10.0.0.0/16)             │ │   │
│   │ • setup-storage │  │   │  │  ┌──────────────────┐ ┌──────────────────┐ │ │   │
│   └─────────────────┘  │   │  │  │  Jenkins Server  │ │   App Server     │ │ │   │
│                        │   │  │  │  (t3.large)      │ │   (t3.micro)     │ │ │   │
│   ┌─────────────────┐  │   │  │  │                  │ │                  │ │ │   │
│   │ Ansible         │──┼──►│  │  │ • Jenkins UI     │ │ • Flask App      │ │ │   │
│   │ Playbooks       │  │   │  │  │ • Docker-in-D    │ │ • Docker         │ │ │   │
│   └─────────────────┘  │   │  │  │ • Pipeline       │ │ • Health checks  │ │ │   │
│                        │   │  │  └────────┬─────────┘ └──────────────────┘ │ │   │
│   ┌─────────────────┐  │   │  │           │ deploys via SSH                │ │   │
│   │ Terraform       │──┘   │  └───────────┼────────────────────────────────┘ │   │
│   │ .tf files       │      │              │                                   │   │
│   └─────────────────┘      │  ┌───────────┴────────────────────────────────┐ │   │
│                            │  │           PERSISTENT STORAGE                │ │   │
│                            │  │  ┌─────────┐ ┌────────────┐ ┌────────────┐ │ │   │
│                            │  │  │Parameter│ │  S3 Bucket │ │  DynamoDB  │ │ │   │
│                            │  │  │ Store   │ │  TF State  │ │  TF Lock   │ │ │   │
│                            │  │  │ Secrets │ │            │ │            │ │ │   │
│                            │  │  └─────────┘ └────────────┘ └────────────┘ │ │   │
│                            │  └────────────────────────────────────────────┘ │   │
│                            └────────────────────────────────────────────────────┘ │
│                                                                                    │
│   EXTERNAL INTEGRATIONS:    ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│                             │Docker Hub│  │  JIRA    │  │  Email   │              │
│                             │(Registry)│  │(Tracking)│  │(Notif.)  │              │
│                             └──────────┘  └──────────┘  └──────────┘              │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## 2.2 Network Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        VPC: 10.0.0.0/16                                   │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                     Internet Gateway                                 │ │
│  └───────────────────────────────┬─────────────────────────────────────┘ │
│                                  │                                        │
│  ┌───────────────────────────────┼─────────────────────────────────────┐ │
│  │                         Route Table                                  │ │
│  │   0.0.0.0/0 → Internet Gateway                                      │ │
│  │   10.0.0.0/16 → Local                                               │ │
│  └───────────────────────────────┼─────────────────────────────────────┘ │
│                                  │                                        │
│    ┌─────────────────────────────┴─────────────────────────────────┐     │
│    │                                                               │     │
│    ▼                                                               ▼     │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐     │
│  │    Public Subnet 1           │  │    Public Subnet 2           │     │
│  │    10.0.1.0/24               │  │    10.0.2.0/24               │     │
│  │    us-east-1a                │  │    us-east-1b                │     │
│  │                              │  │                              │     │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │     │
│  │  │   JENKINS SERVER       │  │  │  │   APPLICATION SERVER   │  │     │
│  │  │                        │  │  │  │                        │  │     │
│  │  │   Instance: t3.large   │  │  │  │   Instance: t3.micro   │  │     │
│  │  │   vCPU: 2              │  │  │  │   vCPU: 2              │  │     │
│  │  │   RAM: 8 GB            │  │  │  │   RAM: 1 GB            │  │     │
│  │  │   Disk: 30 GB gp3      │  │  │  │   Disk: 20 GB gp3      │  │     │
│  │  │                        │  │  │  │                        │  │     │
│  │  │   Elastic IP: ✓        │  │  │  │   Elastic IP: ✓        │  │     │
│  │  │                        │  │  │  │                        │  │     │
│  │  │   Ports:               │  │  │  │   Ports:               │  │     │
│  │  │   • 22 (SSH)           │  │  │  │   • 22 (SSH)           │  │     │
│  │  │   • 8080 (Jenkins)     │  │  │  │   • 80 (HTTP)          │  │     │
│  │  │   • 50000 (Agent)      │  │  │  │   • 443 (HTTPS)        │  │     │
│  │  │   • 443 (HTTPS)        │  │  │  │   • 5000 (Flask int)   │  │     │
│  │  └────────────────────────┘  │  │  └────────────────────────┘  │     │
│  └──────────────────────────────┘  └──────────────────────────────┘     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     S3 VPC Endpoint (Gateway)                       │ │
│  │   Allows private access to S3 for Terraform state                  │ │
│  │   Cost: FREE                                                        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

## 2.3 Security Group Rules (Firewall)

### Jenkins Server Security Group

| Direction | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Inbound | 22 | TCP | Your IP | SSH access for admin |
| Inbound | 8080 | TCP | 0.0.0.0/0 | Jenkins Web UI |
| Inbound | 50000 | TCP | VPC CIDR | Jenkins agent communication |
| Inbound | 443 | TCP | 0.0.0.0/0 | HTTPS (future SSL) |
| Outbound | All | All | 0.0.0.0/0 | Internet access |

### Application Server Security Group

| Direction | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Inbound | 22 | TCP | Jenkins SG | SSH from Jenkins for deployment |
| Inbound | 22 | TCP | Your IP | SSH access for admin |
| Inbound | 80 | TCP | 0.0.0.0/0 | HTTP application |
| Inbound | 443 | TCP | 0.0.0.0/0 | HTTPS application |
| Inbound | 5000 | TCP | VPC CIDR | Flask internal (dev) |
| Outbound | All | All | 0.0.0.0/0 | Internet access |

---

# 3. Infrastructure as Code (Terraform)

## 3.1 Terraform File Structure

```
infrastructure/terraform/
├── main.tf              # Provider config, data sources, locals
├── vpc.tf               # VPC, subnets, IGW, route tables
├── security_groups.tf   # Firewall rules for Jenkins & App
├── jenkins.tf           # Jenkins EC2 instance + EIP
├── app.tf               # Application EC2 instance + EIP
├── iam.tf               # IAM roles, policies, instance profiles
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values (IPs, etc.)
├── backend.tf           # S3 backend config (auto-generated)
└── terraform.tfvars     # Your credentials (GITIGNORED)
```

## 3.2 Resource Inventory (22 Resources)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM MANAGED RESOURCES                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  NETWORKING (7 resources)                                                │
│  ├── aws_vpc.main                    VPC 10.0.0.0/16                    │
│  ├── aws_internet_gateway.main       Internet access                     │
│  ├── aws_subnet.public[0]            10.0.1.0/24 (us-east-1a)           │
│  ├── aws_subnet.public[1]            10.0.2.0/24 (us-east-1b)           │
│  ├── aws_route_table.public          Routes to IGW                       │
│  ├── aws_route_table_association[0]  Subnet 1 association               │
│  ├── aws_route_table_association[1]  Subnet 2 association               │
│  └── aws_vpc_endpoint.s3             S3 gateway endpoint                │
│                                                                          │
│  COMPUTE (4 resources)                                                   │
│  ├── aws_instance.jenkins            t3.large, Jenkins server           │
│  ├── aws_instance.app                t3.micro, Application server       │
│  ├── aws_eip.jenkins                 Static IP for Jenkins              │
│  └── aws_eip.app                     Static IP for App                  │
│                                                                          │
│  SECURITY (2 resources)                                                  │
│  ├── aws_security_group.jenkins      Firewall for Jenkins               │
│  └── aws_security_group.app          Firewall for App                   │
│                                                                          │
│  IAM (6 resources)                                                       │
│  ├── aws_iam_role.jenkins            Role for Jenkins EC2               │
│  ├── aws_iam_role.app                Role for App EC2                   │
│  ├── aws_iam_role_policy.jenkins     Inline policy for Jenkins          │
│  ├── aws_iam_role_policy.app         Inline policy for App              │
│  ├── aws_iam_instance_profile.jenkins Profile for Jenkins EC2           │
│  └── aws_iam_instance_profile.app     Profile for App EC2               │
│                                                                          │
│  DATA SOURCES (3 resources - read-only)                                  │
│  ├── data.aws_ami.amazon_linux_2023  Latest AL2023 AMI                  │
│  ├── data.aws_availability_zones     Available AZs                       │
│  └── data.aws_caller_identity        Current AWS account                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 3.3 Terraform State Management

### Why Remote State?

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         STATE MANAGEMENT                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   LOCAL STATE (Problems)              REMOTE STATE (Solution)           │
│   ┌─────────────────────┐             ┌─────────────────────┐           │
│   │ terraform.tfstate   │             │      S3 Bucket      │           │
│   │ (on your laptop)    │             │  (AWS cloud)        │           │
│   │                     │             │                     │           │
│   │ ❌ Lost if laptop   │             │ ✅ Always available │           │
│   │    crashes          │             │ ✅ Versioned        │           │
│   │ ❌ Can't share      │             │ ✅ Encrypted        │           │
│   │    with team        │             │ ✅ Backed up        │           │
│   │ ❌ No locking       │             │ ✅ Team accessible  │           │
│   │ ❌ No versioning    │             │                     │           │
│   └─────────────────────┘             └──────────┬──────────┘           │
│                                                  │                       │
│                                       ┌──────────▼──────────┐           │
│                                       │    DynamoDB Table   │           │
│                                       │  (State Locking)    │           │
│                                       │                     │           │
│                                       │ Prevents concurrent │           │
│                                       │ state modifications │           │
│                                       └─────────────────────┘           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### State Backend Configuration

```hcl
# backend.tf (auto-generated by setup-aws-storage.sh)
terraform {
  backend "s3" {
    bucket         = "devops-tfstate-632008729195"
    key            = "devops-testing-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devops-tfstate-lock"
  }
}
```

## 3.4 EC2 User Data (Cloud-Init)

The Jenkins EC2 instance runs this script at first boot:

```bash
#!/bin/bash
# Executed automatically by AWS when instance launches

# 1. Update system packages
dnf update -y

# 2. Install required packages
dnf install -y docker git python3 python3-pip jq curl wget unzip

# 3. Start Docker service
systemctl enable docker
systemctl start docker

# 4. Add ec2-user to docker group
usermod -aG docker ec2-user

# 5. Install Docker Compose v2
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 6. Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && ./aws/install

# 7. Create Jenkins directories
mkdir -p /opt/jenkins/data /opt/jenkins/casc
chown -R 1000:1000 /opt/jenkins

# 8. Signal completion
touch /var/log/user-data-complete
```

---

# 4. Configuration Management (Ansible)

## 4.1 Ansible Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ANSIBLE WORKFLOW                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   CONTROL NODE (Your Machine)                                            │
│   ┌─────────────────────────────────────────────────────────────┐       │
│   │                                                              │       │
│   │   bootstrap-infrastructure.sh                                │       │
│   │          │                                                   │       │
│   │          ▼                                                   │       │
│   │   ┌──────────────────────────────────────────────────────┐  │       │
│   │   │              Ansible Inventory                        │  │       │
│   │   │   [jenkins]                                          │  │       │
│   │   │   jenkins-server ansible_host=<JENKINS_IP>           │  │       │
│   │   │                                                      │  │       │
│   │   │   [app]                                              │  │       │
│   │   │   app-server ansible_host=<APP_IP>                   │  │       │
│   │   │                                                      │  │       │
│   │   │   [all:vars]                                         │  │       │
│   │   │   ansible_user=ec2-user                              │  │       │
│   │   │   ansible_ssh_private_key_file=/path/to/key.pem      │  │       │
│   │   └──────────────────────────────────────────────────────┘  │       │
│   │          │                                                   │       │
│   │          ▼                                                   │       │
│   │   ┌──────────────────────────────────────────────────────┐  │       │
│   │   │              Playbooks                                │  │       │
│   │   │   • jenkins-setup.yml (30+ tasks)                    │  │       │
│   │   │   • app-setup.yml (15+ tasks)                        │  │       │
│   │   └──────────────────────────────────────────────────────┘  │       │
│   │                                                              │       │
│   └──────────────────────────────────────────────────────────────┘       │
│                    │                                │                     │
│                    │ SSH + Key                      │ SSH + Key           │
│                    ▼                                ▼                     │
│   ┌────────────────────────────┐  ┌────────────────────────────┐        │
│   │      JENKINS SERVER        │  │      APP SERVER            │        │
│   │      (Managed Node)        │  │      (Managed Node)        │        │
│   │                            │  │                            │        │
│   │  Ansible installs:         │  │  Ansible installs:         │        │
│   │  • Docker                  │  │  • Docker                  │        │
│   │  • Docker Compose          │  │  • Docker Compose          │        │
│   │  • Jenkins container       │  │  • Python                  │        │
│   │  • 30+ plugins             │  │  • Git                     │        │
│   │  • Firefox + Selenium      │  │                            │        │
│   │  • Pipeline job            │  │                            │        │
│   │  • Credentials             │  │                            │        │
│   └────────────────────────────┘  └────────────────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 4.2 Jenkins Setup Playbook Tasks

The `jenkins-setup.yml` playbook executes these tasks in order:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    JENKINS SETUP PLAYBOOK TASKS                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PHASE 1: System Dependencies                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 1. Wait for system to be ready (SSH connection)                  │    │
│  │ 2. Install packages: python3, pip, git, jq, wget, unzip         │    │
│  │ 3. Verify Docker is installed (from cloud-init)                  │    │
│  │ 4. Install Docker Compose v2 plugin                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  PHASE 2: Jenkins Preparation                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 5. Create directories: /opt/jenkins/{data,casc,backup}          │    │
│  │ 6. Create pipeline job config.xml                                │    │
│  │ 7. Create Docker Hub credentials files                           │    │
│  │ 8. Deploy Jenkins CasC configuration (YAML)                      │    │
│  │ 9. Copy plugins list                                             │    │
│  │ 10. Create docker-compose.yml                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  PHASE 3: Container Deployment                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 11. Login to Docker Hub                                          │    │
│  │ 12. Pull Jenkins image (jenkins/jenkins:lts-jdk17)              │    │
│  │ 13. Start Jenkins via Docker Compose                             │    │
│  │ 14. Wait for Jenkins to be ready (health check)                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  PHASE 4: Container Configuration                                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 15. Install Python in Jenkins container                          │    │
│  │ 16. Install Docker CLI in Jenkins container                      │    │
│  │ 17. Install Firefox ESR for E2E tests                            │    │
│  │ 18. Install Xvfb (virtual display)                               │    │
│  │ 19. Download and install GeckoDriver v0.34.0                     │    │
│  │ 20. Verify all tool installations                                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  PHASE 5: Plugin Installation                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 21. Install 30+ plugins via jenkins-plugin-cli                   │    │
│  │ 22. Restart Jenkins to load plugins                              │    │
│  │ 23. Wait for Jenkins restart (health check)                      │    │
│  │ 24. Display credentials summary                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## 4.3 Jenkins Docker Compose Configuration

```yaml
# /opt/jenkins/docker-compose.yml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins
    restart: unless-stopped
    
    ports:
      - "8080:8080"     # Web UI
      - "50000:50000"   # Agent port
    
    volumes:
      - /opt/jenkins/data:/var/jenkins_home     # Persistent data
      - /opt/jenkins/casc:/var/jenkins_casc     # Config as Code
      - /var/run/docker.sock:/var/run/docker.sock  # Docker-in-Docker
    
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - CASC_JENKINS_CONFIG=/var/jenkins_casc/jenkins.yaml
      - DOCKER_HUB_USERNAME=${DOCKER_HUB_USERNAME}
```

## 4.4 Installed Components Matrix

### Jenkins Plugins (30+)

| Category | Plugin | Purpose |
|----------|--------|---------|
| **Core Framework** | structs | Data structures for plugins |
| | workflow-step-api | Pipeline step API |
| | workflow-api | Pipeline API |
| | workflow-support | Pipeline support classes |
| | scm-api | SCM abstraction |
| **Pipeline** | workflow-job | Pipeline job type |
| | workflow-cps | Groovy CPS engine |
| | workflow-aggregator | Pipeline suite |
| | pipeline-model-definition | Declarative Pipeline |
| | pipeline-model-api | Pipeline model API |
| | pipeline-model-extensions | Pipeline extensions |
| | pipeline-groovy-lib | Shared libraries |
| | pipeline-stage-view | Stage visualization |
| | pipeline-utility-steps | Utility steps |
| **SCM** | workflow-scm-step | SCM checkout step |
| | git | Git plugin |
| | git-client | Git client |
| | github | GitHub integration |
| **Build Tools** | timestamper | Build timestamps |
| | ansicolor | Colored console output |
| | docker-workflow | Docker pipeline steps |
| **Testing** | junit | JUnit test results |
| | htmlpublisher | HTML report publishing |
| **Security** | credentials-binding | Credentials in builds |
| | ssh-agent | SSH agent |
| | ssh-credentials | SSH credentials |
| **Post-Build** | ws-cleanup | Workspace cleanup |
| | email-ext | Email notifications |
| **Configuration** | configuration-as-code | Jenkins CasC |
| | job-dsl | Job DSL plugin |
| **Utilities** | http_request | HTTP requests |

### E2E Testing Tools (Inside Jenkins Container)

| Tool | Version | Location | Purpose |
|------|---------|----------|---------|
| Firefox ESR | Latest | /usr/bin/firefox | Headless browser |
| GeckoDriver | 0.34.0 | /usr/local/bin/geckodriver | Selenium WebDriver |
| Xvfb | Latest | /usr/bin/Xvfb | Virtual display |
| Python 3 | Latest | /usr/bin/python3 | Test runner |
| Docker CLI | Latest | /usr/bin/docker | Container operations |

---

# 5. CI/CD Pipeline (Jenkins)

## 5.1 Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     JENKINS PIPELINE (10 STAGES)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌────────┐                                                                │
│    │ START  │                                                                │
│    └───┬────┘                                                                │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 1: Setup Environment                                         │  │
│    │  • Create Python 3.9 virtual environment                            │  │
│    │  • Install pip dependencies from requirements.txt                   │  │
│    │  • Install testing tools: flake8, pylint, bandit, pytest-html      │  │
│    │  Duration: ~60 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 2: Code Quality (PARALLEL)                                   │  │
│    │  ┌──────────────┬──────────────┬──────────────┐                    │  │
│    │  │   Flake8     │   Pylint     │   Bandit     │                    │  │
│    │  │ (style)      │ (quality)    │ (security)   │                    │  │
│    │  └──────────────┴──────────────┴──────────────┘                    │  │
│    │  All run simultaneously to save time                                │  │
│    │  Duration: ~30 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 3: Unit Tests (MANDATORY)                                    │  │
│    │  • pytest tests/unit/ + tests/test_calc.py                         │  │
│    │  • Code coverage report (XML + HTML)                                │  │
│    │  • JUnit XML report for Jenkins                                     │  │
│    │  • HTML test report                                                 │  │
│    │  Duration: ~45 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 4: Integration Tests (MANDATORY)                             │  │
│    │  • pytest tests/integration/                                        │  │
│    │  • API endpoint testing                                             │  │
│    │  • Database interaction tests                                       │  │
│    │  Duration: ~60 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 5: E2E Tests (Selenium + Firefox)                            │  │
│    │  • Start Xvfb virtual display on :99                                │  │
│    │  • Launch Firefox in headless mode                                  │  │
│    │  • pytest tests/e2e/ (9 test cases)                                 │  │
│    │  • Web interface interaction tests                                  │  │
│    │  Duration: ~90 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 6: Performance Tests (Locust)                                │  │
│    │  • Start Flask application in background                            │  │
│    │  • Run Locust load test: 10 users, 30 seconds                      │  │
│    │  • Generate HTML performance report                                 │  │
│    │  • CSV metrics export                                               │  │
│    │  Duration: ~45 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 7: Build Docker Image                                        │  │
│    │  • Multi-stage Dockerfile                                           │  │
│    │  • Tag: {username}/devops-testing-app:{BUILD}-{COMMIT}             │  │
│    │  • Tag: {username}/devops-testing-app:latest                        │  │
│    │  Duration: ~120 seconds                                             │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 8: Push to Docker Hub                                        │  │
│    │  • Login with credentials from secrets                              │  │
│    │  • Push versioned tag                                               │  │
│    │  • Push latest tag                                                  │  │
│    │  Duration: ~60 seconds                                              │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 9: Deploy to Staging (CONDITIONAL)                           │  │
│    │  • Requires: DEPLOY_TO_STAGING = true                               │  │
│    │  • SSH to app server                                                │  │
│    │  • Pull new Docker image                                            │  │
│    │  • Restart container                                                │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │  STAGE 10: Deploy to Production (CONDITIONAL + APPROVAL)            │  │
│    │  • Requires: DEPLOY_TO_PRODUCTION = true                            │  │
│    │  • Manual approval gate                                             │  │
│    │  • Zero-downtime deployment                                         │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                     │
│        ▼                                                                     │
│    ┌────────────────────────────────────────────────────────────────────┐   │
│    │                       POST ACTIONS                                  │   │
│    │  ┌──────────────────────────────────────────────────────────────┐ │   │
│    │  │ ALWAYS:                                                      │ │   │
│    │  │ • Archive all reports (reports/**, htmlcov/**)               │ │   │
│    │  │ • Workspace cleanup                                          │ │   │
│    │  └──────────────────────────────────────────────────────────────┘ │   │
│    │  ┌──────────────────────────────────────────────────────────────┐ │   │
│    │  │ ON SUCCESS:                                                  │ │   │
│    │  │ • Send success email with build details                      │ │   │
│    │  │ • Include links to coverage report                           │ │   │
│    │  └──────────────────────────────────────────────────────────────┘ │   │
│    │  ┌──────────────────────────────────────────────────────────────┐ │   │
│    │  │ ON FAILURE:                                                  │ │   │
│    │  │ • Create JIRA issue automatically                            │ │   │
│    │  │ • Send failure email with JIRA link                          │ │   │
│    │  │ • Include failed stage information                           │ │   │
│    │  └──────────────────────────────────────────────────────────────┘ │   │
│    └────────────────────────────────────────────────────────────────────┘   │
│        │                                                                     │
│        ▼                                                                     │
│    ┌────────┐                                                                │
│    │  END   │                                                                │
│    └────────┘                                                                │
│                                                                              │
│    TOTAL DURATION: ~8-12 minutes (typical successful build)                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 5.2 Pipeline Parameters

| Parameter | Default | Type | Description |
|-----------|---------|------|-------------|
| `RUN_PERFORMANCE_TESTS` | `true` | Boolean | Execute Locust load tests |
| `RUN_E2E_TESTS` | `true` | Boolean | Execute Selenium/Firefox tests |
| `DEPLOY_TO_STAGING` | `false` | Boolean | Deploy to staging server |
| `DEPLOY_TO_PRODUCTION` | `false` | Boolean | Deploy to production (with approval) |

## 5.3 Environment Variables

```groovy
environment {
    // Python
    PYTHON_VERSION = '3.9'
    VENV_DIR = 'venv'
    
    // Docker
    DOCKER_REGISTRY = 'docker.io'
    DOCKER_IMAGE = "${DOCKER_HUB_USERNAME}/devops-testing-app"
    
    // Versioning
    GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    VERSION_TAG = "${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
    
    // JIRA
    JIRA_PROJECT_KEY = 'CICD'
    
    // Notifications
    NOTIFICATION_EMAIL = 'daniel.mazhbits@gmail.com'
}
```

## 5.4 Reports Generated

```
reports/
├── flake8.txt                 # Style violations
├── pylint.txt                 # Code quality issues
├── bandit-report.json         # Security findings
├── unit-tests.xml             # JUnit format (Jenkins parses)
├── unit-tests.html            # Human-readable report
├── integration-tests.xml      # JUnit format
├── integration-tests.html     # Human-readable report
├── e2e-tests.xml              # JUnit format
├── e2e-tests.html             # Human-readable report
├── performance-report.html    # Locust load test results
├── performance_stats.csv      # Raw metrics
├── performance_failures.csv   # Failed requests
└── coverage.xml               # Coverage in Cobertura format

htmlcov/
└── index.html                 # Interactive coverage browser
```

---

# 6. Testing Strategy

## 6.1 Testing Pyramid

```
                            ┌─────────────┐
                            │             │
                            │   Manual    │  ◄── Exploratory testing
                            │   Testing   │      (occasional)
                            │             │
                            └──────┬──────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    │      E2E Tests (9)          │  ◄── Browser automation
                    │    Selenium + Firefox       │      ~90 seconds
                    │                             │
                    └──────────────┬──────────────┘
                                   │
         ┌─────────────────────────┴─────────────────────────┐
         │                                                    │
         │           Integration Tests (10+)                  │  ◄── API testing
         │              Flask test client                     │      ~60 seconds
         │                                                    │
         └─────────────────────────┬─────────────────────────┘
                                   │
┌──────────────────────────────────┴──────────────────────────────────┐
│                                                                      │
│                        Unit Tests (20+)                              │  ◄── Function testing
│                       Pure Python, fast                              │      ~45 seconds
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

                    MORE TESTS = FASTER = CHEAPER
```

## 6.2 Test Types Explained

### Unit Tests (`tests/unit/`, `tests/test_calc.py`)

```python
# tests/test_calc.py
from app.calculator import add, subtract, multiply, divide

def test_add():
    """Basic addition test"""
    assert add(2, 3) == 5

def test_divide():
    """Division with edge cases"""
    assert divide(10, 2) == 5
    with pytest.raises(ValueError):
        divide(10, 0)  # Division by zero
```

**Characteristics:**
- No external dependencies
- Test single functions/methods
- Execute in milliseconds
- ~20+ test cases

### Integration Tests (`tests/integration/`)

```python
# tests/integration/test_api.py
def test_health_endpoint(client):
    """Test /health returns 200"""
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'

def test_create_user(client):
    """Test user creation API"""
    response = client.post('/api/users', json={
        'name': 'Test User',
        'email': 'test@example.com'
    })
    assert response.status_code == 201
```

**Characteristics:**
- Uses Flask test client
- Tests API contracts
- Database interactions
- ~10+ test cases

### E2E Tests (`tests/e2e/`)

```python
# tests/e2e/test_web_interface.py
from selenium.webdriver import Firefox
from selenium.webdriver.firefox.options import Options

@pytest.fixture
def driver(app_server):
    """Create Firefox WebDriver in headless mode"""
    options = Options()
    options.add_argument("--headless")
    driver = Firefox(options=options)
    yield driver
    driver.quit()

class TestWebInterface:
    def test_page_loads(self, driver, app_server):
        """Verify page loads successfully"""
        driver.get(app_server)
        assert "DevOps Testing App" in driver.title
    
    def test_button_interactions(self, driver, app_server):
        """Verify all buttons are present"""
        driver.get(app_server)
        buttons = driver.find_elements(By.TAG_NAME, "button")
        assert len(buttons) >= 5
```

**Characteristics:**
- Real browser automation
- Simulates user interactions
- Full-stack testing
- 9 test cases

### Performance Tests (`tests/performance/`)

```python
# tests/performance/locustfile.py
from locust import HttpUser, task, between

class WebsiteUser(HttpUser):
    wait_time = between(1, 3)
    
    @task(10)
    def health_check(self):
        """Frequent health check"""
        self.client.get("/health")
    
    @task(5)
    def get_users(self):
        """API call to list users"""
        self.client.get("/api/users")
    
    @task(2)
    def create_user(self):
        """Create a user"""
        self.client.post("/api/users", json={
            "name": f"User {time.time()}",
            "email": f"user{time.time()}@test.com"
        })
```

**Test Parameters:**
- Users: 10 concurrent
- Spawn rate: 2 users/second
- Duration: 30 seconds
- Metrics: Response times, failures, RPS

---

# 7. Security & Secrets Management

## 7.1 Secrets Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SECRETS MANAGEMENT FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   INITIAL SETUP (One-time)                                                   │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │   terraform.tfvars (LOCAL - GITIGNORED)                              │  │
│   │   ┌─────────────────────────────────────────────────────────────┐   │  │
│   │   │ docker_hub_username = "danielmazh"                          │   │  │
│   │   │ docker_hub_token    = "dckr_pat_xxx..."                     │   │  │
│   │   │ github_token        = "ghp_xxx..."                          │   │  │
│   │   │ jira_api_token      = "ATATT..."                            │   │  │
│   │   │ jenkins_admin_password = "DevOps2026!"                      │   │  │
│   │   └─────────────────────────────────────────────────────────────┘   │  │
│   └────────────────────────────────────┬─────────────────────────────────┘  │
│                                        │                                     │
│                                        ▼                                     │
│                            ./scripts/setup-aws-storage.sh                    │
│                                        │                                     │
│                                        ▼                                     │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │         AWS PARAMETER STORE (Persistent - Encrypted)                 │  │
│   │   ┌─────────────────────────────────────────────────────────────┐   │  │
│   │   │ /devops/docker_hub_username   String        "danielmazh"    │   │  │
│   │   │ /devops/docker_hub_token      SecureString  "dckr_pat_..."  │   │  │
│   │   │ /devops/github_username       String        "danielmazh"    │   │  │
│   │   │ /devops/github_token          SecureString  "ghp_xxx..."    │   │  │
│   │   │ /devops/jira_url              String        "https://..."   │   │  │
│   │   │ /devops/jira_email            String        "daniel@..."    │   │  │
│   │   │ /devops/jira_api_token        SecureString  "ATATT..."      │   │  │
│   │   │ /devops/jenkins_password      SecureString  "DevOps2026!"   │   │  │
│   │   │ /devops/ssh_key_path          String        "/path/to/key"  │   │  │
│   │   └─────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │  │
│   │   ENCRYPTION: AES-256 with AWS KMS                                   │  │
│   │   COST: FREE (Standard tier, up to 10,000 parameters)               │  │
│   └────────────────────────────────────┬─────────────────────────────────┘  │
│                                        │                                     │
│   DEPLOYMENT (Every time)              │                                     │
│   ┌────────────────────────────────────┴─────────────────────────────────┐  │
│   │   bootstrap-infrastructure.sh                                        │  │
│   │   ┌─────────────────────────────────────────────────────────────┐   │  │
│   │   │ 1. Load from Parameter Store (aws ssm get-parameter)        │   │  │
│   │   │ 2. Export as environment variables                          │   │  │
│   │   │ 3. Pass to Ansible as extra-vars                            │   │  │
│   │   └─────────────────────────────────────────────────────────────┘   │  │
│   └────────────────────────────────────┬─────────────────────────────────┘  │
│                                        │                                     │
│                                        ▼                                     │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │   JENKINS CONTAINER (Runtime)                                        │  │
│   │   ┌─────────────────────────────────────────────────────────────┐   │  │
│   │   │ /var/jenkins_home/secrets/docker-username                   │   │  │
│   │   │ /var/jenkins_home/secrets/docker-password                   │   │  │
│   │   │                                                             │   │  │
│   │   │ Jenkinsfile reads:                                          │   │  │
│   │   │ DOCKER_USER=$(cat /var/jenkins_home/secrets/docker-username)│   │  │
│   │   │ DOCKER_PASS=$(cat /var/jenkins_home/secrets/docker-password)│   │  │
│   │   └─────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │  │
│   │   SECRETS NEVER IN:                                                  │  │
│   │   ❌ Git repository                                                  │  │
│   │   ❌ Console logs                                                    │  │
│   │   ❌ Environment echoes                                              │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 7.2 Security Best Practices Implemented

| Practice | Implementation |
|----------|----------------|
| **Secrets not in Git** | `terraform.tfvars` in `.gitignore` |
| **Encrypted at rest** | AWS Parameter Store SecureString |
| **Encrypted in transit** | HTTPS/TLS for all AWS API calls |
| **Least privilege** | IAM roles with minimal permissions |
| **No hardcoded secrets** | All secrets from Parameter Store |
| **Secrets rotation** | Easy to update in Parameter Store |
| **Audit logging** | CloudTrail logs Parameter Store access |
| **Network isolation** | VPC with security groups |

## 7.3 IAM Permissions

### Jenkins EC2 Role Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/devops/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::devops-tfstate-*",
        "arn:aws:s3:::devops-tfstate-*/*"
      ]
    }
  ]
}
```

---

# 8. Cost Management & Optimization

## 8.1 Cost Breakdown

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS COST ANALYSIS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   RUNNING STATE (Infrastructure Active)                                      │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ Resource                      │ Hourly    │ Daily    │ Monthly       │ │
│   ├───────────────────────────────┼───────────┼──────────┼───────────────┤ │
│   │ Jenkins EC2 (t3.large)        │ $0.0832   │ $2.00    │ $60.00        │ │
│   │ App EC2 (t3.micro)            │ $0.0104   │ $0.25    │ $7.50         │ │
│   │ EBS Volumes (50GB total)      │ $0.00028  │ $0.007   │ $4.00         │ │
│   │ Elastic IPs (2)               │ $0.005*   │ $0.12    │ $3.60         │ │
│   │ Data Transfer (estimate)      │ ~$0.00    │ ~$0.00   │ ~$5.00        │ │
│   ├───────────────────────────────┼───────────┼──────────┼───────────────┤ │
│   │ TOTAL (Running)               │ ~$0.10    │ ~$2.40   │ ~$80.00       │ │
│   └───────────────────────────────┴───────────┴──────────┴───────────────┘ │
│   * EIPs free when attached to running instance                             │
│                                                                              │
│   STOPPED STATE (After destroy, storage kept)                               │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ Resource                      │ Monthly Cost                          │ │
│   ├───────────────────────────────┼───────────────────────────────────────┤ │
│   │ S3 Bucket (state files)       │ ~$0.001 (few KB of storage)          │ │
│   │ DynamoDB Table                │ FREE (on-demand, minimal usage)       │ │
│   │ Parameter Store               │ FREE (Standard tier)                  │ │
│   ├───────────────────────────────┼───────────────────────────────────────┤ │
│   │ TOTAL (Stopped)               │ ~$0.001/month (essentially FREE)     │ │
│   └───────────────────────────────┴───────────────────────────────────────┘ │
│                                                                              │
│   DELETED STATE (After --delete-storage)                                    │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ Resource                      │ Monthly Cost                          │ │
│   ├───────────────────────────────┼───────────────────────────────────────┤ │
│   │ Everything                    │ $0.00                                 │ │
│   │ TOTAL                         │ $0.00                                 │ │
│   └───────────────────────────────┴───────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 8.2 Cost Optimization Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     RECOMMENDED USAGE PATTERN                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   SCENARIO 1: Learning/Development (8 hours/day)                            │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ • Deploy in morning: ./scripts/bootstrap-infrastructure.sh            │ │
│   │ • Use for 8 hours                                                     │ │
│   │ • Destroy at night: ./scripts/destroy-infrastructure.sh               │ │
│   │                                                                       │ │
│   │ Cost: 8h × $0.10/h × 20 days = ~$16/month                            │ │
│   │ Savings vs always-on: 80%                                             │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   SCENARIO 2: Weekend Project (16 hours/week)                               │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ • Deploy Saturday morning                                             │ │
│   │ • Use throughout weekend                                              │ │
│   │ • Destroy Sunday night                                                │ │
│   │                                                                       │ │
│   │ Cost: 16h × $0.10/h × 4 weeks = ~$6.40/month                         │ │
│   │ Savings vs always-on: 92%                                             │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   SCENARIO 3: Occasional Use (4 hours/week)                                 │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │ • Deploy only when needed                                             │ │
│   │ • Complete task                                                       │ │
│   │ • Destroy immediately                                                 │ │
│   │                                                                       │ │
│   │ Cost: 4h × $0.10/h × 4 weeks = ~$1.60/month                          │ │
│   │ Savings vs always-on: 98%                                             │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# 9. Operations & Troubleshooting

## 9.1 Common Issues & Solutions

### Issue 1: Terraform State Lock

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ERROR: Error acquiring the state lock                                        │
│ Lock ID: 43b726d0-4ff9-33f8-e490-18a80e262b2a                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ CAUSE: Previous Terraform run interrupted or crashed                         │
│                                                                              │
│ SOLUTION:                                                                    │
│ cd infrastructure/terraform                                                  │
│ terraform force-unlock 43b726d0-4ff9-33f8-e490-18a80e262b2a                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Issue 2: Jenkins Plugin Error

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ERROR: NoSuchMethodError: No such DSL method 'junit' found                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ CAUSE: Plugin not installed or not loaded after restart                      │
│                                                                              │
│ SOLUTION:                                                                    │
│ ssh -i $KEY ec2-user@$JENKINS_IP                                            │
│ docker exec jenkins jenkins-plugin-cli --plugins junit                       │
│ docker restart jenkins                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Issue 3: SSH Connection Refused

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ERROR: ssh: connect to host X.X.X.X port 22: Connection refused              │
├─────────────────────────────────────────────────────────────────────────────┤
│ CAUSE: Instance not fully booted or security group issue                     │
│                                                                              │
│ SOLUTION:                                                                    │
│ 1. Wait 2-3 minutes for cloud-init to complete                              │
│ 2. Verify security group allows SSH from your IP                            │
│ 3. Check instance state in AWS Console                                       │
│ 4. Verify correct SSH key file                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Issue 4: Docker Hub Push Failed

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ERROR: denied: requested access to the resource is denied                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ CAUSE: Invalid Docker Hub token or wrong username                           │
│                                                                              │
│ SOLUTION:                                                                    │
│ 1. Verify token in Parameter Store:                                         │
│    aws ssm get-parameter --name "/devops/docker_hub_token" --with-decryption│
│ 2. Update if needed:                                                         │
│    aws ssm put-parameter --name "/devops/docker_hub_token" \                │
│        --value "NEW_TOKEN" --type SecureString --overwrite                  │
│ 3. Redeploy Ansible:                                                        │
│    ./scripts/bootstrap-infrastructure.sh --skip-terraform                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Issue 5: E2E Tests Fail - Firefox Not Found

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ERROR: selenium.common.exceptions.WebDriverException: 'firefox' not found    │
├─────────────────────────────────────────────────────────────────────────────┤
│ CAUSE: Firefox not installed in Jenkins container                            │
│                                                                              │
│ SOLUTION:                                                                    │
│ ssh -i $KEY ec2-user@$JENKINS_IP                                            │
│ docker exec -u root jenkins apt-get update                                   │
│ docker exec -u root jenkins apt-get install -y firefox-esr xvfb             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 9.2 Debug Commands Reference

```bash
# View Jenkins container logs
ssh -i $KEY ec2-user@$JENKINS_IP "docker logs jenkins --tail 100"

# Check Jenkins container status
ssh -i $KEY ec2-user@$JENKINS_IP "docker ps -a | grep jenkins"

# View cloud-init logs (EC2 user-data)
ssh -i $KEY ec2-user@$JENKINS_IP "cat /var/log/user-data.log"

# Check installed Jenkins plugins
ssh -i $KEY ec2-user@$JENKINS_IP "docker exec jenkins ls /var/jenkins_home/plugins"

# Verify Terraform state
cd infrastructure/terraform && terraform state list

# Check Parameter Store secrets
aws ssm describe-parameters --query 'Parameters[?starts_with(Name, `/devops/`)].Name'

# Get specific parameter value
aws ssm get-parameter --name "/devops/docker_hub_username" --query 'Parameter.Value' --output text

# List running EC2 instances
aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=devops-testing-app" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
    --output table
```

---

# 10. Deployment Workflow

## 10.1 First-Time Setup

```bash
# 1. Clone repository
git clone https://github.com/danielmazh/devops-ci-cd-exercise.git
cd devops-ci-cd-exercise

# 2. Create terraform.tfvars (use template)
cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
# Edit with your credentials...

# 3. Set up AWS storage (S3, DynamoDB, Parameter Store)
./scripts/setup-aws-storage.sh

# 4. Initialize Terraform with S3 backend
cd infrastructure/terraform
terraform init -migrate-state
cd ../..

# 5. Deploy everything
./scripts/bootstrap-infrastructure.sh
```

## 10.2 Daily Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DAILY WORKFLOW                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   START OF DAY                                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │   ./scripts/bootstrap-infrastructure.sh                              │   │
│   │                                                                      │   │
│   │   What happens:                                                      │   │
│   │   1. Loads credentials from Parameter Store                          │   │
│   │   2. Creates 22 AWS resources via Terraform                          │   │
│   │   3. Configures servers via Ansible                                  │   │
│   │   4. Installs 30+ Jenkins plugins                                    │   │
│   │   5. Displays access URLs                                            │   │
│   │                                                                      │   │
│   │   Duration: 10-15 minutes                                            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│        │                                                                     │
│        ▼                                                                     │
│   ACCESS JENKINS: http://<JENKINS_IP>:8080                                  │
│   Login: admin / DevOps2026!                                                │
│        │                                                                     │
│        ▼                                                                     │
│   DURING THE DAY                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │   1. Make code changes                                               │   │
│   │   2. git add . && git commit -m "message" && git push               │   │
│   │   3. Jenkins automatically runs pipeline                             │   │
│   │   4. View results in Jenkins UI                                      │   │
│   │   5. Repeat                                                          │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│        │                                                                     │
│        ▼                                                                     │
│   END OF DAY                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │   ./scripts/destroy-infrastructure.sh                                │   │
│   │                                                                      │   │
│   │   When prompted:                                                     │   │
│   │   • Type 'destroy' to confirm                                        │   │
│   │   • Press 'K' to KEEP storage (credentials stay in Parameter Store) │   │
│   │                                                                      │   │
│   │   Duration: 3-5 minutes                                              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 10.3 End of Course Cleanup

```bash
# Destroy EVERYTHING including storage
./scripts/destroy-infrastructure.sh --delete-storage

# When prompted, type: DELETE ALL

# Verify zero resources remain
aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=devops-testing-app" \
    --query 'Reservations[].Instances[].InstanceId'
# Should return: []

aws s3 ls | grep devops-tfstate
# Should return: nothing

aws ssm describe-parameters \
    --query 'Parameters[?starts_with(Name, `/devops/`)].Name'
# Should return: []

# Final cost: $0.00/month
```

## 10.4 Quick Reference Card

| Command | Purpose |
|---------|---------|
| `./scripts/setup-aws-storage.sh` | First-time setup of AWS storage |
| `./scripts/bootstrap-infrastructure.sh` | Deploy everything |
| `./scripts/bootstrap-infrastructure.sh --dry-run` | Preview without changes |
| `./scripts/bootstrap-infrastructure.sh --skip-terraform` | Only Ansible (re-configure) |
| `./scripts/destroy-infrastructure.sh` | Destroy infra, keep storage |
| `./scripts/destroy-infrastructure.sh --force` | Non-interactive destroy |
| `./scripts/destroy-infrastructure.sh --delete-storage` | Delete EVERYTHING |
| `terraform force-unlock <LOCK_ID>` | Unlock stuck state |
| `terraform state list` | Show managed resources |
| `terraform output` | Show IPs and endpoints |

---

# 11. Project Structure - Complete File Tree

## 11.1 Full Project Tree with Explanations

```
devops-ci-cd-exercise/
│
├── .gitignore                          # Git ignore rules (secrets, state files, caches)
├── README.md                           # Main project documentation
├── requirements.txt                    # Python dependencies (Flask, pytest, selenium, locust)
├── pytest.ini                          # Pytest configuration (markers, options)
├── env.template                        # Template for environment variables
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                         APPLICATION CODE                                   ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── main.py                             # Flask application entry point
├── calc.py                             # Calculator module (demo functions)
│
├── app/                                # Main application package
│   ├── __init__.py                     # Flask app factory, configuration
│   │
│   ├── routes/                         # API endpoint definitions
│   │   ├── __init__.py                 # Routes package init
│   │   ├── user_routes.py              # User CRUD endpoints (/api/users)
│   │   └── product_routes.py           # Product endpoints (/api/products)
│   │
│   └── templates/                      # Jinja2 HTML templates
│       └── index.html                  # Main web UI template
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                           TEST SUITES                                      ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── tests/                              # All test code
│   ├── __init__.py                     # Tests package init
│   ├── test_calc.py                    # Calculator unit tests
│   ├── test_calc_oop.py                # OOP calculator tests
│   │
│   ├── unit/                           # Unit tests (fast, isolated)
│   │   ├── __init__.py
│   │   ├── test_routes.py              # Route handler tests
│   │   └── test_utils.py               # Utility function tests
│   │
│   ├── integration/                    # Integration tests (API testing)
│   │   ├── __init__.py
│   │   └── test_api.py                 # Full API endpoint tests
│   │
│   ├── e2e/                            # End-to-end tests (browser automation)
│   │   ├── __init__.py
│   │   └── test_web_interface.py       # Selenium + Firefox tests (9 cases)
│   │
│   └── performance/                    # Load/stress tests
│       ├── __init__.py
│       └── locustfile.py               # Locust load test scenarios
│
├── reports/                            # Generated test reports (gitignored)
│   ├── pytest_report.html              # HTML test results
│   ├── pytest_report.xml               # JUnit XML for Jenkins
│   └── performance-report.html         # Locust performance report
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                         DOCKER CONFIGURATION                               ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── docker/                             # Docker build files
│   ├── Dockerfile                      # Multi-stage app build (prod-ready)
│   ├── Dockerfile.jenkins              # Custom Jenkins image (optional)
│   ├── .dockerignore                   # Files to exclude from Docker context
│   ├── docker-compose.yml              # Local development compose
│   ├── docker-compose.prod.yml         # Production compose config
│   ├── plugins.txt                     # Jenkins plugins list (for custom image)
│   │
│   └── casc/                           # Jenkins Configuration as Code
│       └── jenkins.yaml                # Jenkins settings (local dev)
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                         JENKINS CI/CD                                      ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── jenkins/                            # Jenkins pipeline definitions
│   ├── Jenkinsfile                     # Main pipeline (10 stages)
│   ├── Jenkinsfile.prod                # Production pipeline variant
│   ├── plugins.txt                     # Required plugins list
│   │
│   ├── casc/                           # Configuration as Code
│   │   └── jenkins.yaml                # Jenkins system config
│   │
│   └── jobs/                           # Job DSL definitions
│       └── seed-job.groovy             # Creates pipeline jobs programmatically
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                      AUTOMATION SCRIPTS                                    ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── scripts/                            # Bash automation scripts
│   │
│   │   # MAIN SCRIPTS (use these)
│   ├── bootstrap-infrastructure.sh     # 🚀 DEPLOY EVERYTHING (main entry point)
│   ├── destroy-infrastructure.sh       # 💥 TEAR DOWN infrastructure
│   ├── setup-aws-storage.sh            # 🔧 Create S3, DynamoDB, Parameter Store
│   │
│   │   # UTILITY SCRIPTS
│   ├── build-and-push.sh               # Build & push Docker image manually
│   ├── health-check.sh                 # Check if services are running
│   ├── run-tests.sh                    # Run test suite locally
│   └── get-jenkins-password.sh         # Retrieve initial Jenkins password
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                   INFRASTRUCTURE AS CODE                                   ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
├── infrastructure/
│   │
│   │   ┌─────────────────────────────────────────────────────────────────────┐
│   │   │                    TERRAFORM (AWS Resources)                         │
│   │   └─────────────────────────────────────────────────────────────────────┘
│   │
│   ├── terraform/                      # Infrastructure as Code
│   │   │
│   │   │   # CONFIGURATION
│   │   ├── main.tf                     # Provider config, data sources, locals
│   │   ├── variables.tf                # Input variable definitions
│   │   ├── outputs.tf                  # Output values (IPs, URLs)
│   │   ├── terraform.tfvars.example    # Template for your credentials
│   │   ├── terraform.tfvars            # YOUR CREDENTIALS (gitignored!)
│   │   ├── backend.tf                  # S3 backend config (auto-generated)
│   │   │
│   │   │   # NETWORKING
│   │   ├── vpc.tf                      # VPC, subnets, IGW, route tables
│   │   ├── security_groups.tf          # Firewall rules (ports 22, 80, 8080, etc)
│   │   │
│   │   │   # COMPUTE
│   │   ├── jenkins.tf                  # Jenkins EC2 (t3.large) + Elastic IP
│   │   ├── app.tf                      # App EC2 (t3.micro) + Elastic IP
│   │   │
│   │   │   # SECURITY
│   │   └── iam.tf                      # IAM roles, policies, instance profiles
│   │
│   │
│   │   ┌─────────────────────────────────────────────────────────────────────┐
│   │   │                    ANSIBLE (Server Configuration)                    │
│   │   └─────────────────────────────────────────────────────────────────────┘
│   │
│   └── ansible/                        # Configuration management
│       │
│       ├── ansible.cfg                 # Ansible settings (SSH, timeout, etc)
│       │
│       │   # INVENTORY (which servers to configure)
│       ├── inventory/
│       │   ├── aws_ec2.yml             # Dynamic AWS inventory plugin config
│       │   └── staging.ini             # Auto-generated static inventory
│       │
│       │   # VARIABLES (configuration values)
│       ├── group_vars/
│       │   ├── all.yml                 # Variables for ALL hosts
│       │   ├── jenkins.yml             # Jenkins-specific variables
│       │   └── app.yml                 # App server-specific variables
│       │
│       │   # PLAYBOOKS (what to do)
│       ├── playbooks/
│       │   ├── jenkins-setup.yml       # 🔧 Configure Jenkins server (30+ tasks)
│       │   ├── app-setup.yml           # 🔧 Configure App server
│       │   ├── deploy-app.yml          # 🚀 Deploy new app version
│       │   └── rollback.yml            # ⏪ Rollback to previous version
│       │
│       │   # ROLES (reusable configurations)
│       └── roles/
│           │
│           ├── jenkins/                # Jenkins role
│           │   ├── tasks/
│           │   │   └── main.yml        # Jenkins installation tasks
│           │   ├── handlers/
│           │   │   └── main.yml        # Restart handlers
│           │   ├── templates/
│           │   │   ├── docker-compose.yml.j2   # Jenkins Docker Compose
│           │   │   └── jenkins-casc.yaml.j2    # Jenkins CasC template
│           │   └── files/
│           │       └── plugins.txt     # Plugin list to install
│           │
│           └── docker-app/             # Application deployment role
│               ├── tasks/
│               │   └── main.yml        # App deployment tasks
│               ├── handlers/
│               │   └── main.yml        # Container restart handlers
│               └── templates/
│                   └── docker-compose.yml.j2   # App Docker Compose
│
│
│   ╔═══════════════════════════════════════════════════════════════════════════╗
│   ║                         DOCUMENTATION                                      ║
│   ╚═══════════════════════════════════════════════════════════════════════════╝
│
└── presentation/                       # Presentation materials
    └── DevOps-CI-CD-Complete-Guide.md  # This comprehensive guide
```

## 11.2 Key Directories Explained

| Directory | Purpose | When Modified |
|-----------|---------|---------------|
| `app/` | Flask application source code | When adding features |
| `tests/` | All test suites (unit, integration, e2e, performance) | When adding tests |
| `docker/` | Container build configurations | When changing build process |
| `jenkins/` | CI/CD pipeline definitions | When modifying pipeline |
| `scripts/` | Automation bash scripts | When changing deployment process |
| `infrastructure/terraform/` | AWS resource definitions | When changing cloud architecture |
| `infrastructure/ansible/` | Server configuration | When changing server setup |
| `reports/` | Generated test reports | Auto-generated by tests |
| `presentation/` | Documentation and guides | When updating docs |

## 11.3 Critical Files Reference

### Files You MUST Configure (One-time)

| File | Purpose | Contains |
|------|---------|----------|
| `infrastructure/terraform/terraform.tfvars` | Your credentials | AWS keys, Docker Hub token, etc. |

### Files Auto-Generated (Don't Edit Manually)

| File | Generated By | Purpose |
|------|--------------|---------|
| `infrastructure/terraform/backend.tf` | `setup-aws-storage.sh` | S3 backend config |
| `infrastructure/ansible/inventory/staging.ini` | `bootstrap-infrastructure.sh` | Server IPs |
| `reports/*` | Jenkins pipeline | Test results |

### Files That Control Pipeline Behavior

| File | What It Controls |
|------|------------------|
| `jenkins/Jenkinsfile` | Pipeline stages, tests, deployment |
| `requirements.txt` | Python dependencies installed |
| `infrastructure/ansible/roles/jenkins/files/plugins.txt` | Jenkins plugins installed |
| `docker/Dockerfile` | How app container is built |

## 11.4 File Flow During Deployment

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FILE FLOW DURING DEPLOYMENT                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   1. YOU RUN: ./scripts/bootstrap-infrastructure.sh                          │
│              │                                                               │
│              ▼                                                               │
│   2. READS: terraform.tfvars ─────────────► Gets AWS credentials            │
│              │                                                               │
│              ▼                                                               │
│   3. RUNS:  terraform apply ──────────────► Uses: main.tf, vpc.tf,          │
│              │                               jenkins.tf, app.tf, iam.tf,     │
│              │                               security_groups.tf              │
│              │                               CREATES: 22 AWS resources       │
│              ▼                                                               │
│   4. CREATES: inventory/staging.ini ──────► Writes Jenkins/App IPs          │
│              │                                                               │
│              ▼                                                               │
│   5. RUNS:  ansible-playbook jenkins-setup.yml                              │
│              │         │                                                     │
│              │         ├─► USES: roles/jenkins/tasks/main.yml               │
│              │         ├─► USES: roles/jenkins/templates/*.j2               │
│              │         └─► USES: roles/jenkins/files/plugins.txt            │
│              │                                                               │
│              ▼                                                               │
│   6. ON JENKINS SERVER:                                                      │
│      ├─► /opt/jenkins/docker-compose.yml (from template)                    │
│      ├─► /opt/jenkins/casc/jenkins.yaml (from template)                     │
│      ├─► /opt/jenkins/data/jobs/devops-testing-app/config.xml               │
│      └─► /opt/jenkins/data/secrets/* (credentials)                          │
│              │                                                               │
│              ▼                                                               │
│   7. JENKINS PIPELINE USES: jenkins/Jenkinsfile                              │
│      ├─► Clones repo from GitHub                                            │
│      ├─► Runs tests from tests/                                              │
│      ├─► Builds from docker/Dockerfile                                       │
│      └─► Reports to reports/                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# Summary

This project demonstrates a complete, production-ready DevOps CI/CD infrastructure that:

1. **Automates Everything** - One command deploys entire infrastructure
2. **Follows Best Practices** - IaC, Configuration as Code, Secrets Management
3. **Comprehensive Testing** - Unit, Integration, E2E, Performance
4. **Cost Optimized** - Pay only for what you use
5. **Secure by Design** - No secrets in code, encrypted storage
6. **Well Documented** - Clear architecture and troubleshooting guides

**Key Technologies:**
- Terraform (Infrastructure)
- Ansible (Configuration)
- Jenkins (CI/CD)
- Docker (Containers)
- AWS (Cloud Platform)
- Python (Application & Tests)
- Selenium (E2E Testing)
- Locust (Performance Testing)

---

**Author:** Daniel Mazhbits  
**Course:** DevOps Training - Lesson 47  
**Date:** February 2026

---

*One command. Complete CI/CD. Production ready.*
