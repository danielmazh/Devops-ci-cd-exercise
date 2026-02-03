# DevOps CI/CD Exercise - Master Implementation Plan

**Author:** Senior Principal Engineer  
**Date:** 2026-02-02  
**Status:** Ready for Execution  
**Estimated Duration:** 4-6 hours

---

## 1. Background & Problem

This project requires implementing a production-grade CI/CD pipeline for a Flask-based REST API. The current state includes:

| Component | Status | Gap |
|-----------|--------|-----|
| Flask App | ✅ Complete | None |
| Tests (Unit/Integration/E2E/Perf) | ✅ Complete | None |
| Basic Jenkinsfile | ✅ Exists | Needs enhancement |
| Dockerfile | ❌ Missing | **Must create** |
| Docker Compose | ❌ Missing | Recommended |
| Terraform (AWS) | ❌ Missing | **Must create** |
| Ansible Playbooks | ❌ Missing | **Must create** |
| JIRA Integration | ❌ Missing | **Must add** |
| Slack Notifications | ❌ Missing | Optional |
| Production Jenkinsfile | ❌ Missing | **Must enhance** |

### Root Requirements (from README)

1. Docker container with all dependencies
2. Jenkins pipeline with proper test gating
3. Docker Hub artifact push
4. AWS staging deployment (Terraform + Ansible)
5. JIRA issue creation on failure
6. Email/Slack notifications
7. Test report integration in Jenkins UI

---

## 2. Questions & Answers

| # | Question | Answer |
|---|----------|--------|
| Q1 | Which Python version for Docker? | **Python 3.11-slim** (LTS, security patches, small image) |
| Q2 | Docker Hub registry? | User must provide `DOCKER_HUB_USERNAME` as env var |
| Q3 | AWS region for deployment? | `us-east-1` (default, configurable) |
| Q4 | EC2 instance type? | `t3.micro` (free tier eligible) |
| Q5 | JIRA API version? | JIRA REST API v3 (cloud) or v2 (server) |
| Q6 | Skip perf tests logic? | Only run when `ENVIRONMENT=production` |
| Q7 | Versioning strategy? | Semantic versioning from git tags + BUILD_NUMBER |

---

## 3. Final Project Structure

```
devops-ci-cd-exercise/
├── .cursor/                          # Cursor IDE config
│   ├── design-logs/
│   │   └── 0001_devops_cicd_master_plan.md
│   ├── helpers-scripts/
│   ├── logs/
│   ├── plans/
│   ├── rules/
│   └── wip/
│
├── app/                              # Flask application (existing)
│   ├── __init__.py
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── product_routes.py
│   │   └── user_routes.py
│   └── templates/
│       └── index.html
│
├── docker/                           # 🆕 Docker configuration
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── .dockerignore
│
├── infrastructure/                   # 🆕 IaC configurations
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpc.tf
│   │   ├── ec2.tf
│   │   ├── security_groups.tf
│   │   └── terraform.tfvars.example
│   │
│   └── ansible/
│       ├── inventory/
│       │   ├── staging.ini
│       │   └── production.ini
│       ├── playbooks/
│       │   ├── deploy.yml
│       │   ├── setup.yml
│       │   └── rollback.yml
│       ├── roles/
│       │   └── docker-app/
│       │       ├── tasks/
│       │       │   └── main.yml
│       │       ├── handlers/
│       │       │   └── main.yml
│       │       └── templates/
│       │           └── docker-compose.yml.j2
│       └── ansible.cfg
│
├── jenkins/                          # 🔄 Enhanced Jenkins config
│   ├── Jenkinsfile                   # Main pipeline (enhanced)
│   ├── Jenkinsfile.prod              # Production pipeline
│   └── shared/
│       └── vars/
│           ├── notifySlack.groovy
│           ├── createJiraIssue.groovy
│           └── deployToAWS.groovy
│
├── scripts/                          # 🆕 Utility scripts
│   ├── build-and-push.sh
│   ├── run-tests.sh
│   ├── health-check.sh
│   └── version.sh
│
├── tests/                            # Existing tests
│   ├── __init__.py
│   ├── conftest.py                   # 🆕 Shared fixtures
│   ├── unit/
│   ├── integration/
│   ├── e2e/
│   └── performance/
│
├── reports/                          # Test reports (existing)
│
├── .env.example                      # 🆕 Environment template
├── .gitignore                        # 🆕 Git ignore rules
├── calc.py
├── main.py
├── pytest.ini
├── README.md
└── requirements.txt
```

---

## 4. Environment Setup

### 4.1 Required VS Code/Cursor Extensions

```bash
# Install via command palette or CLI
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-azuretools.vscode-docker
code --install-extension HashiCorp.terraform
code --install-extension redhat.ansible
code --install-extension ms-vscode.makefile-tools
code --install-extension eamodio.gitlens
code --install-extension streetsidesoftware.code-spell-checker
```

### 4.2 Local Dependencies

```bash
# macOS
brew install python@3.11 docker docker-compose terraform ansible jq

# Verify installations
python3 --version     # >= 3.11
docker --version      # >= 24.0
terraform --version   # >= 1.5
ansible --version     # >= 2.15
```

### 4.3 Python Virtual Environment

```bash
cd /Users/danielmazmazhbits/CProjects/devops-ci-cd-exercise

# Create and activate venv
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Install dev/lint tools
pip install flake8 pylint bandit black isort mypy
```

### 4.4 Docker Desktop Configuration

```
Settings → Resources:
  - CPUs: 4
  - Memory: 8GB
  - Disk: 60GB

Settings → Kubernetes:
  - Enable Kubernetes (optional for local k8s testing)
```

---

## 5. Implementation Plan - Sequential Execution

### Phase 1: Docker Setup (Steps 1-5)

---

#### **STEP 1: Create Docker Directory Structure**

```bash
mkdir -p docker
touch docker/Dockerfile docker/docker-compose.yml docker/docker-compose.prod.yml docker/.dockerignore
```

**Checkpoint:** `ls -la docker/` shows 4 files

---

#### **STEP 2: Create Dockerfile**

**File:** `docker/Dockerfile`

```dockerfile
# =============================================================================
# DevOps Testing App - Production Dockerfile
# =============================================================================
# Multi-stage build for minimal image size and security
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
# Stage 2: Production
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS production

# Security: Create non-root user
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --chown=appuser:appgroup app/ ./app/
COPY --chown=appuser:appgroup main.py .
COPY --chown=appuser:appgroup calc.py .

# Security hardening
RUN chmod -R 550 /app && \
    chmod 440 /app/*.py

# Environment configuration
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=main.py \
    FLASK_ENV=production \
    PORT=5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/health')" || exit 1

# Switch to non-root user
USER appuser

# Expose port
EXPOSE ${PORT}

# Production server command
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--threads", "2", "--timeout", "120", "main:app"]

# -----------------------------------------------------------------------------
# Stage 3: Development (optional target)
# -----------------------------------------------------------------------------
FROM production AS development

USER root

# Install dev dependencies
RUN pip install --no-cache-dir pytest pytest-cov flake8

# Reset permissions for development
RUN chmod -R 755 /app

USER appuser

ENV FLASK_ENV=development \
    FLASK_DEBUG=1

CMD ["python", "main.py"]
```

**Validation:**
```bash
docker build -f docker/Dockerfile -t devops-app:test .
echo $?  # Should be 0
```

---

#### **STEP 3: Create .dockerignore**

**File:** `docker/.dockerignore`

```
# Git
.git
.gitignore

# Python
__pycache__
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
.venv/
ENV/
.eggs/
*.egg-info/
*.egg

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/
reports/

# IDE
.cursor/
.vscode/
.idea/
*.swp
*.swo
*~

# Docker
docker/
Dockerfile*
docker-compose*

# Infrastructure
infrastructure/

# Jenkins
jenkins/

# Documentation
*.md
docs/

# Misc
.env*
*.log
tmp/
```

---

#### **STEP 4: Create docker-compose.yml (Development)**

**File:** `docker/docker-compose.yml`

```yaml
# =============================================================================
# DevOps Testing App - Development Docker Compose
# =============================================================================
version: "3.9"

services:
  app:
    build:
      context: ..
      dockerfile: docker/Dockerfile
      target: development
    container_name: devops-app-dev
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
      - SECRET_KEY=dev-secret-key-change-in-production
    volumes:
      - ../app:/app/app:ro
      - ../main.py:/app/main.py:ro
      - ../calc.py:/app/calc.py:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
    restart: unless-stopped
    networks:
      - devops-network

  # Optional: Redis for caching (future enhancement)
  # redis:
  #   image: redis:7-alpine
  #   container_name: devops-redis
  #   ports:
  #     - "6379:6379"
  #   networks:
  #     - devops-network

networks:
  devops-network:
    driver: bridge
    name: devops-network
```

---

#### **STEP 5: Create docker-compose.prod.yml (Production)**

**File:** `docker/docker-compose.prod.yml`

```yaml
# =============================================================================
# DevOps Testing App - Production Docker Compose
# =============================================================================
version: "3.9"

services:
  app:
    image: ${DOCKER_REGISTRY:-dockerhub}/${DOCKER_IMAGE:-devops-testing-app}:${IMAGE_TAG:-latest}
    container_name: devops-app-prod
    ports:
      - "80:5000"
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=${SECRET_KEY}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    restart: always
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - devops-network

networks:
  devops-network:
    driver: bridge
    name: devops-network
```

**Validation - Phase 1 Complete:**
```bash
# Build and run locally
cd /Users/danielmazmazhbits/CProjects/devops-ci-cd-exercise
docker-compose -f docker/docker-compose.yml build
docker-compose -f docker/docker-compose.yml up -d

# Test health endpoint
sleep 5
curl -s http://localhost:5000/health | jq .
# Expected: {"service":"devops-testing-app","status":"healthy"}

# Cleanup
docker-compose -f docker/docker-compose.yml down
```

---

### Phase 2: Infrastructure as Code (Steps 6-15)

---

#### **STEP 6: Create Infrastructure Directory Structure**

```bash
mkdir -p infrastructure/terraform
mkdir -p infrastructure/ansible/{inventory,playbooks,roles/docker-app/{tasks,handlers,templates}}
```

---

#### **STEP 7: Create Terraform main.tf**

**File:** `infrastructure/terraform/main.tf`

```hcl
# =============================================================================
# DevOps Testing App - Main Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state configuration (uncomment for production)
  # backend "s3" {
  #   bucket         = "devops-terraform-state"
  #   key            = "devops-testing-app/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-testing-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

---

#### **STEP 8: Create Terraform variables.tf**

**File:** `infrastructure/terraform/variables.tf`

```hcl
# =============================================================================
# DevOps Testing App - Terraform Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (staging/production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-testing-app"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict in production!
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}
```

---

#### **STEP 9: Create Terraform vpc.tf**

**File:** `infrastructure/terraform/vpc.tf`

```hcl
# =============================================================================
# DevOps Testing App - VPC Configuration
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

---

#### **STEP 10: Create Terraform security_groups.tf**

**File:** `infrastructure/terraform/security_groups.tf`

```hcl
# =============================================================================
# DevOps Testing App - Security Groups
# =============================================================================

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for DevOps Testing App"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # App port (internal)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "App internal access"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

---

#### **STEP 11: Create Terraform ec2.tf**

**File:** `infrastructure/terraform/ec2.tf`

```hcl
# =============================================================================
# DevOps Testing App - EC2 Instance
# =============================================================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    dnf update -y
    
    # Install Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    
    # Add ec2-user to docker group
    usermod -aG docker ec2-user
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create app directory
    mkdir -p /opt/devops-app
    chown ec2-user:ec2-user /opt/devops-app
    
    echo "User data script completed successfully" > /var/log/user-data-complete.log
  EOF
  )

  tags = {
    Name = "${local.name_prefix}-app-server"
  }

  lifecycle {
    ignore_changes = [ami]  # Prevent recreation on AMI updates
  }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-app-eip"
  }
}
```

---

#### **STEP 12: Create Terraform outputs.tf**

**File:** `infrastructure/terraform/outputs.tf`

```hcl
# =============================================================================
# DevOps Testing App - Terraform Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "app_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "app_public_ip" {
  description = "Application public IP (Elastic IP)"
  value       = aws_eip.app.public_ip
}

output "app_public_dns" {
  description = "Application public DNS"
  value       = aws_eip.app.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.app.public_ip}"
}

output "ansible_inventory_entry" {
  description = "Ansible inventory entry"
  value       = "${aws_eip.app.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem"
}
```

---

#### **STEP 13: Create terraform.tfvars.example**

**File:** `infrastructure/terraform/terraform.tfvars.example`

```hcl
# =============================================================================
# DevOps Testing App - Terraform Variables Example
# Copy this file to terraform.tfvars and fill in your values
# =============================================================================

aws_region    = "us-east-1"
environment   = "staging"
project_name  = "devops-testing-app"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# EC2 Configuration
instance_type = "t3.micro"
key_name      = "your-ssh-key-name"  # REQUIRED: Your AWS key pair name

# Security
allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]  # Restrict to your IP!

# Docker Configuration
docker_image = "your-dockerhub-username/devops-testing-app"
docker_tag   = "latest"
```

---

#### **STEP 14: Create Ansible Configuration**

**File:** `infrastructure/ansible/ansible.cfg`

```ini
[defaults]
inventory = inventory/staging.ini
remote_user = ec2-user
private_key_file = ~/.ssh/devops-key.pem
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
```

**File:** `infrastructure/ansible/inventory/staging.ini`

```ini
[staging]
# Add your EC2 IP after terraform apply
# Example: 54.123.45.67 ansible_user=ec2-user

[staging:vars]
environment=staging
docker_registry=docker.io
docker_image=devops-testing-app
docker_tag=latest
app_port=5000
```

**File:** `infrastructure/ansible/inventory/production.ini`

```ini
[production]
# Add your EC2 IP after terraform apply
# Example: 54.123.45.67 ansible_user=ec2-user

[production:vars]
environment=production
docker_registry=docker.io
docker_image=devops-testing-app
docker_tag=latest
app_port=5000
```

---

#### **STEP 15: Create Ansible Playbooks and Roles**

**File:** `infrastructure/ansible/playbooks/setup.yml`

```yaml
---
# =============================================================================
# DevOps Testing App - Server Setup Playbook
# =============================================================================
- name: Setup application server
  hosts: all
  become: yes
  
  tasks:
    - name: Update all packages
      dnf:
        name: "*"
        state: latest
      when: ansible_os_family == "RedHat"

    - name: Install required packages
      dnf:
        name:
          - docker
          - python3-pip
          - git
          - curl
          - jq
        state: present
      when: ansible_os_family == "RedHat"

    - name: Start and enable Docker service
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: yes

    - name: Install Docker Compose
      get_url:
        url: "https://github.com/docker/compose/releases/latest/download/docker-compose-{{ ansible_system }}-{{ ansible_architecture }}"
        dest: /usr/local/bin/docker-compose
        mode: '0755'

    - name: Create application directory
      file:
        path: /opt/devops-app
        state: directory
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"
        mode: '0755'

    - name: Login to Docker Hub
      docker_login:
        username: "{{ docker_hub_username }}"
        password: "{{ docker_hub_token }}"
      when: docker_hub_username is defined and docker_hub_token is defined
```

**File:** `infrastructure/ansible/playbooks/deploy.yml`

```yaml
---
# =============================================================================
# DevOps Testing App - Deployment Playbook
# =============================================================================
- name: Deploy application
  hosts: all
  become: yes
  
  vars:
    app_dir: /opt/devops-app
    
  tasks:
    - name: Create docker-compose file
      template:
        src: ../roles/docker-app/templates/docker-compose.yml.j2
        dest: "{{ app_dir }}/docker-compose.yml"
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"
        mode: '0644'

    - name: Pull latest Docker image
      docker_image:
        name: "{{ docker_registry }}/{{ docker_image }}:{{ docker_tag }}"
        source: pull
        force_source: yes

    - name: Stop existing containers
      docker_compose:
        project_src: "{{ app_dir }}"
        state: absent
      ignore_errors: yes

    - name: Start application containers
      docker_compose:
        project_src: "{{ app_dir }}"
        state: present
        pull: yes

    - name: Wait for application to be healthy
      uri:
        url: "http://localhost:{{ app_port }}/health"
        method: GET
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 10
      delay: 5

    - name: Display deployment status
      debug:
        msg: "Application deployed successfully! Health status: {{ health_check.json }}"
```

**File:** `infrastructure/ansible/playbooks/rollback.yml`

```yaml
---
# =============================================================================
# DevOps Testing App - Rollback Playbook
# =============================================================================
- name: Rollback application
  hosts: all
  become: yes
  
  vars:
    app_dir: /opt/devops-app
    
  tasks:
    - name: Get previous image tag
      shell: docker images --format "{{ '{{' }}.Tag{{ '}}' }}" {{ docker_registry }}/{{ docker_image }} | head -2 | tail -1
      register: previous_tag
      
    - name: Set rollback tag
      set_fact:
        rollback_tag: "{{ previous_tag.stdout | default('latest') }}"

    - name: Stop current containers
      docker_compose:
        project_src: "{{ app_dir }}"
        state: absent
      ignore_errors: yes

    - name: Update docker-compose with rollback tag
      lineinfile:
        path: "{{ app_dir }}/docker-compose.yml"
        regexp: 'image:.*{{ docker_image }}'
        line: "    image: {{ docker_registry }}/{{ docker_image }}:{{ rollback_tag }}"

    - name: Start application with previous version
      docker_compose:
        project_src: "{{ app_dir }}"
        state: present

    - name: Wait for application to be healthy
      uri:
        url: "http://localhost:{{ app_port }}/health"
        method: GET
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 10
      delay: 5

    - name: Display rollback status
      debug:
        msg: "Rollback to {{ rollback_tag }} completed! Health: {{ health_check.json }}"
```

**File:** `infrastructure/ansible/roles/docker-app/templates/docker-compose.yml.j2`

```yaml
version: "3.9"

services:
  app:
    image: {{ docker_registry }}/{{ docker_image }}:{{ docker_tag }}
    container_name: devops-app-{{ environment }}
    ports:
      - "{{ app_port }}:5000"
    environment:
      - FLASK_ENV={{ environment }}
      - SECRET_KEY={{ secret_key | default('change-me-in-production') }}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default:
    name: devops-network-{{ environment }}
```

**File:** `infrastructure/ansible/roles/docker-app/tasks/main.yml`

```yaml
---
- name: Include deploy tasks
  include_tasks: ../../playbooks/deploy.yml
```

**File:** `infrastructure/ansible/roles/docker-app/handlers/main.yml`

```yaml
---
- name: Restart Docker
  systemd:
    name: docker
    state: restarted

- name: Restart application
  docker_compose:
    project_src: /opt/devops-app
    state: present
    restarted: yes
```

**Validation - Phase 2:**
```bash
# Validate Terraform
cd infrastructure/terraform
terraform init
terraform validate
terraform fmt -check

# Validate Ansible
cd ../ansible
ansible-playbook --syntax-check playbooks/setup.yml
ansible-playbook --syntax-check playbooks/deploy.yml
```

---

### Phase 3: Enhanced Jenkins Pipeline (Steps 16-20)

---

#### **STEP 16: Create Utility Scripts**

**File:** `scripts/build-and-push.sh`

```bash
#!/bin/bash
# =============================================================================
# DevOps Testing App - Build and Push Docker Image
# =============================================================================
set -euo pipefail

# Configuration
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
DOCKER_IMAGE="${DOCKER_IMAGE:-devops-testing-app}"
BUILD_NUMBER="${BUILD_NUMBER:-local}"
GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"

# Generate version tag
VERSION_TAG="${BUILD_NUMBER}-${GIT_COMMIT}"

echo "=========================================="
echo "Building Docker Image"
echo "=========================================="
echo "Registry: ${DOCKER_REGISTRY}"
echo "Image: ${DOCKER_IMAGE}"
echo "Tag: ${VERSION_TAG}"
echo "=========================================="

# Build the image
docker build \
    -f docker/Dockerfile \
    -t "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${VERSION_TAG}" \
    -t "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VERSION="${VERSION_TAG}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    .

echo "=========================================="
echo "Pushing to Registry"
echo "=========================================="

# Push both tags
docker push "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${VERSION_TAG}"
docker push "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"

echo "=========================================="
echo "Build Complete!"
echo "Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${VERSION_TAG}"
echo "=========================================="
```

**File:** `scripts/run-tests.sh`

```bash
#!/bin/bash
# =============================================================================
# DevOps Testing App - Test Runner Script
# =============================================================================
set -euo pipefail

TEST_TYPE="${1:-all}"
ENVIRONMENT="${ENVIRONMENT:-development}"

# Create reports directory
mkdir -p reports htmlcov

echo "=========================================="
echo "Running Tests: ${TEST_TYPE}"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="

case "${TEST_TYPE}" in
    unit)
        pytest tests/unit/ -v \
            --cov=app \
            --cov-report=xml:reports/coverage.xml \
            --cov-report=html:htmlcov \
            --junit-xml=reports/unit-tests.xml
        ;;
    integration)
        pytest tests/integration/ -v \
            --junit-xml=reports/integration-tests.xml
        ;;
    e2e)
        pytest tests/e2e/ -v \
            --junit-xml=reports/e2e-tests.xml
        ;;
    performance)
        if [[ "${ENVIRONMENT}" == "production" ]]; then
            echo "Running performance tests..."
            python main.py &
            APP_PID=$!
            sleep 5
            
            locust -f tests/performance/locustfile.py \
                --headless \
                --users 10 \
                --spawn-rate 2 \
                --run-time 30s \
                --host http://localhost:5000 \
                --html reports/performance-report.html
            
            kill $APP_PID || true
        else
            echo "Skipping performance tests (not production environment)"
        fi
        ;;
    all)
        # Run all except performance (unless production)
        pytest tests/unit/ tests/integration/ -v \
            --cov=app \
            --cov-report=xml:reports/coverage.xml \
            --cov-report=html:htmlcov \
            --junit-xml=reports/all-tests.xml
        ;;
    *)
        echo "Unknown test type: ${TEST_TYPE}"
        echo "Usage: $0 [unit|integration|e2e|performance|all]"
        exit 1
        ;;
esac

echo "=========================================="
echo "Tests Complete!"
echo "=========================================="
```

**File:** `scripts/health-check.sh`

```bash
#!/bin/bash
# =============================================================================
# DevOps Testing App - Health Check Script
# =============================================================================
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-5000}"
MAX_RETRIES="${3:-10}"
RETRY_DELAY="${4:-5}"

echo "Checking health of ${HOST}:${PORT}..."

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "http://${HOST}:${PORT}/health" > /dev/null 2>&1; then
        echo "✅ Health check passed!"
        curl -s "http://${HOST}:${PORT}/health" | jq .
        exit 0
    fi
    echo "Attempt ${i}/${MAX_RETRIES} failed. Retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
done

echo "❌ Health check failed after ${MAX_RETRIES} attempts"
exit 1
```

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

---

#### **STEP 17: Create Jenkins Shared Library Functions**

**File:** `jenkins/shared/vars/notifySlack.groovy`

```groovy
// =============================================================================
// DevOps Testing App - Slack Notification
// =============================================================================

def call(Map config = [:]) {
    def status = config.status ?: 'UNKNOWN'
    def channel = config.channel ?: '#devops-notifications'
    def message = config.message ?: ''
    
    def color = status == 'SUCCESS' ? 'good' : 
                status == 'FAILURE' ? 'danger' : 'warning'
    
    def emoji = status == 'SUCCESS' ? '✅' : 
                status == 'FAILURE' ? '❌' : '⚠️'
    
    def payload = """
    {
        "channel": "${channel}",
        "attachments": [
            {
                "color": "${color}",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "${emoji} Jenkins Build ${status}"
                        }
                    },
                    {
                        "type": "section",
                        "fields": [
                            {"type": "mrkdwn", "text": "*Job:*\\n${env.JOB_NAME}"},
                            {"type": "mrkdwn", "text": "*Build:*\\n#${env.BUILD_NUMBER}"},
                            {"type": "mrkdwn", "text": "*Branch:*\\n${env.BRANCH_NAME ?: 'N/A'}"},
                            {"type": "mrkdwn", "text": "*Duration:*\\n${currentBuild.durationString}"}
                        ]
                    },
                    {
                        "type": "section",
                        "text": {"type": "mrkdwn", "text": "${message}"}
                    },
                    {
                        "type": "actions",
                        "elements": [
                            {
                                "type": "button",
                                "text": {"type": "plain_text", "text": "View Build"},
                                "url": "${env.BUILD_URL}"
                            }
                        ]
                    }
                ]
            }
        ]
    }
    """
    
    if (env.SLACK_WEBHOOK_URL) {
        httpRequest(
            url: env.SLACK_WEBHOOK_URL,
            httpMode: 'POST',
            contentType: 'APPLICATION_JSON',
            requestBody: payload,
            validResponseCodes: '200'
        )
    } else {
        echo "SLACK_WEBHOOK_URL not configured. Skipping Slack notification."
    }
}
```

**File:** `jenkins/shared/vars/createJiraIssue.groovy`

```groovy
// =============================================================================
// DevOps Testing App - JIRA Issue Creation
// =============================================================================

def call(Map config = [:]) {
    def projectKey = config.projectKey ?: 'DEVOPS'
    def issueType = config.issueType ?: 'Bug'
    def summary = config.summary ?: "Jenkins Build Failure: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def description = config.description ?: ''
    def priority = config.priority ?: 'High'
    
    def fullDescription = """
    h2. Build Failure Details
    
    ||Field||Value||
    |Job Name|${env.JOB_NAME}|
    |Build Number|${env.BUILD_NUMBER}|
    |Branch|${env.BRANCH_NAME ?: 'N/A'}|
    |Duration|${currentBuild.durationString}|
    |Build URL|[View Build|${env.BUILD_URL}]|
    |Console Log|[View Console|${env.BUILD_URL}console]|
    
    h2. Description
    ${description}
    
    h2. Failed Stage
    ${env.STAGE_NAME ?: 'Unknown'}
    
    h2. Git Information
    * Commit: ${env.GIT_COMMIT ?: 'N/A'}
    * Author: ${env.GIT_AUTHOR_NAME ?: 'N/A'}
    """
    
    def issuePayload = """
    {
        "fields": {
            "project": {"key": "${projectKey}"},
            "summary": "${summary}",
            "description": ${groovy.json.JsonOutput.toJson(fullDescription)},
            "issuetype": {"name": "${issueType}"},
            "priority": {"name": "${priority}"},
            "labels": ["jenkins", "automated", "build-failure"]
        }
    }
    """
    
    if (env.JIRA_URL && env.JIRA_CREDENTIALS_ID) {
        withCredentials([usernamePassword(
            credentialsId: env.JIRA_CREDENTIALS_ID,
            usernameVariable: 'JIRA_USER',
            passwordVariable: 'JIRA_TOKEN'
        )]) {
            def response = httpRequest(
                url: "${env.JIRA_URL}/rest/api/2/issue",
                httpMode: 'POST',
                contentType: 'APPLICATION_JSON',
                requestBody: issuePayload,
                authentication: env.JIRA_CREDENTIALS_ID,
                validResponseCodes: '201'
            )
            
            def issueKey = readJSON(text: response.content).key
            echo "Created JIRA issue: ${issueKey}"
            return issueKey
        }
    } else {
        echo "JIRA not configured. Skipping issue creation."
        return null
    }
}
```

**File:** `jenkins/shared/vars/deployToAWS.groovy`

```groovy
// =============================================================================
// DevOps Testing App - AWS Deployment
// =============================================================================

def call(Map config = [:]) {
    def environment = config.environment ?: 'staging'
    def dockerImage = config.dockerImage
    def dockerTag = config.dockerTag ?: 'latest'
    def ansibleInventory = config.ansibleInventory ?: "infrastructure/ansible/inventory/${environment}.ini"
    
    echo "=========================================="
    echo "Deploying to AWS ${environment}"
    echo "Image: ${dockerImage}:${dockerTag}"
    echo "=========================================="
    
    dir('infrastructure/ansible') {
        withCredentials([
            sshUserPrivateKey(
                credentialsId: 'aws-ssh-key',
                keyFileVariable: 'SSH_KEY'
            ),
            usernamePassword(
                credentialsId: 'docker-hub-credentials',
                usernameVariable: 'DOCKER_USER',
                passwordVariable: 'DOCKER_PASS'
            )
        ]) {
            sh """
                export ANSIBLE_HOST_KEY_CHECKING=False
                
                ansible-playbook playbooks/deploy.yml \
                    -i ${ansibleInventory} \
                    --private-key=\$SSH_KEY \
                    -e docker_registry=docker.io \
                    -e docker_image=${dockerImage} \
                    -e docker_tag=${dockerTag} \
                    -e docker_hub_username=\$DOCKER_USER \
                    -e docker_hub_token=\$DOCKER_PASS \
                    -e environment=${environment}
            """
        }
    }
    
    echo "Deployment to ${environment} completed!"
}
```

---

#### **STEP 18: Create Enhanced Jenkinsfile**

**File:** `jenkins/Jenkinsfile` (Replace existing)

```groovy
// =============================================================================
// DevOps Testing App - Enhanced Jenkins Pipeline
// =============================================================================

pipeline {
    agent any
    
    environment {
        // Python configuration
        PYTHON_VERSION = '3.11'
        VENV_DIR = 'venv'
        
        // Docker configuration
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_IMAGE = "${env.DOCKER_HUB_USERNAME}/devops-testing-app"
        DOCKER_CREDENTIALS_ID = 'docker-hub-credentials'
        
        // AWS configuration
        AWS_CREDENTIALS_ID = 'aws-credentials'
        AWS_SSH_KEY_ID = 'aws-ssh-key'
        
        // Notification configuration
        JIRA_URL = credentials('jira-url')
        JIRA_CREDENTIALS_ID = 'jira-credentials'
        SLACK_WEBHOOK_URL = credentials('slack-webhook-url')
        
        // Build metadata
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        VERSION_TAG = "${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        // =====================================================================
        // Stage 1: Environment Setup
        // =====================================================================
        stage('Setup Environment') {
            steps {
                script {
                    echo "Setting up Python ${PYTHON_VERSION} environment"
                    
                    sh """
                        python${PYTHON_VERSION} -m venv ${VENV_DIR}
                        . ${VENV_DIR}/bin/activate
                        pip install --upgrade pip
                        pip install -r requirements.txt
                        pip install flake8 pylint bandit
                    """
                }
            }
        }
        
        // =====================================================================
        // Stage 2: Code Quality
        // =====================================================================
        stage('Code Quality') {
            parallel {
                stage('Lint - Flake8') {
                    steps {
                        sh """
                            . ${VENV_DIR}/bin/activate
                            mkdir -p reports
                            flake8 app/ --output-file=reports/flake8.txt \
                                --max-line-length=120 \
                                --ignore=E501,W503 || true
                        """
                    }
                }
                stage('Lint - Pylint') {
                    steps {
                        sh """
                            . ${VENV_DIR}/bin/activate
                            pylint app/ --output=reports/pylint.txt \
                                --exit-zero \
                                --disable=C0114,C0115,C0116
                        """
                    }
                }
                stage('Security - Bandit') {
                    steps {
                        sh """
                            . ${VENV_DIR}/bin/activate
                            bandit -r app/ -f json -o reports/bandit-report.json || true
                        """
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/*.txt,reports/*.json', allowEmptyArchive: true
                }
            }
        }
        
        // =====================================================================
        // Stage 3: Unit Tests
        // =====================================================================
        stage('Unit Tests') {
            steps {
                sh """
                    . ${VENV_DIR}/bin/activate
                    mkdir -p reports htmlcov
                    
                    pytest tests/unit/ tests/test_calc.py -v \
                        --cov=app \
                        --cov-report=xml:reports/coverage.xml \
                        --cov-report=html:htmlcov \
                        --junit-xml=reports/unit-tests.xml \
                        --html=reports/unit-tests.html \
                        --self-contained-html
                """
            }
            post {
                always {
                    junit 'reports/unit-tests.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Unit Test Coverage'
                    ])
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'unit-tests.html',
                        reportName: 'Unit Test Report'
                    ])
                }
            }
        }
        
        // =====================================================================
        // Stage 4: Integration Tests
        // =====================================================================
        stage('Integration Tests') {
            steps {
                sh """
                    . ${VENV_DIR}/bin/activate
                    
                    pytest tests/integration/ -v \
                        --junit-xml=reports/integration-tests.xml \
                        --html=reports/integration-tests.html \
                        --self-contained-html
                """
            }
            post {
                always {
                    junit 'reports/integration-tests.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'integration-tests.html',
                        reportName: 'Integration Test Report'
                    ])
                }
            }
        }
        
        // =====================================================================
        // Stage 5: E2E Tests
        // =====================================================================
        stage('E2E Tests') {
            steps {
                sh """
                    . ${VENV_DIR}/bin/activate
                    export DISPLAY=:99
                    
                    # Start virtual display for headless browser
                    Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
                    sleep 3
                    
                    pytest tests/e2e/ -v \
                        --junit-xml=reports/e2e-tests.xml \
                        --html=reports/e2e-tests.html \
                        --self-contained-html || true
                    
                    killall Xvfb || true
                """
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/e2e-tests.xml'
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'e2e-tests.html',
                        reportName: 'E2E Test Report'
                    ])
                }
            }
        }
        
        // =====================================================================
        // Stage 6: Performance Tests (Production Only)
        // =====================================================================
        stage('Performance Tests') {
            when {
                expression { 
                    return env.ENVIRONMENT == 'production' || 
                           env.BRANCH_NAME == 'main'
                }
            }
            steps {
                sh """
                    . ${VENV_DIR}/bin/activate
                    
                    # Start application
                    python main.py &
                    APP_PID=\$!
                    sleep 5
                    
                    # Run load tests
                    locust -f tests/performance/locustfile.py \
                        --headless \
                        --users 10 \
                        --spawn-rate 2 \
                        --run-time 30s \
                        --host http://localhost:5000 \
                        --html reports/performance-report.html \
                        --csv reports/performance
                    
                    # Cleanup
                    kill \$APP_PID || true
                """
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'performance-report.html',
                        reportName: 'Performance Test Report'
                    ])
                    archiveArtifacts artifacts: 'reports/performance*.csv', allowEmptyArchive: true
                }
            }
        }
        
        // =====================================================================
        // Stage 7: Build Docker Image
        // =====================================================================
        stage('Build Docker Image') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_IMAGE}:${VERSION_TAG}"
                    
                    sh """
                        docker build \
                            -f docker/Dockerfile \
                            -t ${DOCKER_IMAGE}:${VERSION_TAG} \
                            -t ${DOCKER_IMAGE}:latest \
                            --build-arg BUILD_DATE="\$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
                            --build-arg VERSION="${VERSION_TAG}" \
                            --build-arg GIT_COMMIT="${GIT_COMMIT_SHORT}" \
                            .
                    """
                }
            }
        }
        
        // =====================================================================
        // Stage 8: Push to Docker Hub
        // =====================================================================
        stage('Push to Docker Hub') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKER_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo "\$DOCKER_PASS" | docker login -u "\$DOCKER_USER" --password-stdin
                            docker push ${DOCKER_IMAGE}:${VERSION_TAG}
                            docker push ${DOCKER_IMAGE}:latest
                            docker logout
                        """
                    }
                }
            }
        }
        
        // =====================================================================
        // Stage 9: Deploy to Staging
        // =====================================================================
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    deployToAWS(
                        environment: 'staging',
                        dockerImage: DOCKER_IMAGE,
                        dockerTag: VERSION_TAG
                    )
                }
            }
            post {
                success {
                    script {
                        notifySlack(
                            status: 'SUCCESS',
                            message: "Staging deployment successful! Version: ${VERSION_TAG}"
                        )
                    }
                }
            }
        }
        
        // =====================================================================
        // Stage 10: Deploy to Production
        // =====================================================================
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                // Manual approval for production
                input message: 'Deploy to Production?', ok: 'Deploy'
                
                script {
                    deployToAWS(
                        environment: 'production',
                        dockerImage: DOCKER_IMAGE,
                        dockerTag: VERSION_TAG
                    )
                }
            }
            post {
                success {
                    script {
                        notifySlack(
                            status: 'SUCCESS',
                            message: "🚀 Production deployment successful! Version: ${VERSION_TAG}"
                        )
                    }
                }
            }
        }
    }
    
    // =========================================================================
    // Post Actions
    // =========================================================================
    post {
        always {
            // Archive all reports
            archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
            archiveArtifacts artifacts: 'htmlcov/**/*', allowEmptyArchive: true
            
            // Cleanup workspace
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true
            )
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                emailext(
                    subject: "✅ Build Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Successful!</h2>
                        <table>
                            <tr><td><strong>Job:</strong></td><td>${env.JOB_NAME}</td></tr>
                            <tr><td><strong>Build:</strong></td><td>#${env.BUILD_NUMBER}</td></tr>
                            <tr><td><strong>Branch:</strong></td><td>${env.BRANCH_NAME ?: 'N/A'}</td></tr>
                            <tr><td><strong>Version:</strong></td><td>${VERSION_TAG}</td></tr>
                            <tr><td><strong>Duration:</strong></td><td>${currentBuild.durationString}</td></tr>
                        </table>
                        <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
                
                notifySlack(status: 'SUCCESS', message: "Build completed successfully!")
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Create JIRA issue
                def jiraIssue = createJiraIssue(
                    projectKey: 'DEVOPS',
                    summary: "Jenkins Build Failure: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    description: "Build failed on branch ${env.BRANCH_NAME ?: 'unknown'}",
                    priority: 'High'
                )
                
                // Send failure email
                emailext(
                    subject: "❌ Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Failed!</h2>
                        <table>
                            <tr><td><strong>Job:</strong></td><td>${env.JOB_NAME}</td></tr>
                            <tr><td><strong>Build:</strong></td><td>#${env.BUILD_NUMBER}</td></tr>
                            <tr><td><strong>Branch:</strong></td><td>${env.BRANCH_NAME ?: 'N/A'}</td></tr>
                            <tr><td><strong>Duration:</strong></td><td>${currentBuild.durationString}</td></tr>
                            <tr><td><strong>Failed Stage:</strong></td><td>${env.STAGE_NAME ?: 'Unknown'}</td></tr>
                            ${jiraIssue ? "<tr><td><strong>JIRA Issue:</strong></td><td>${jiraIssue}</td></tr>" : ''}
                        </table>
                        <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                        <p><a href="${env.BUILD_URL}console">View Console Log</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
                
                notifySlack(
                    status: 'FAILURE',
                    message: "Build failed! ${jiraIssue ? "JIRA: ${jiraIssue}" : ''}"
                )
            }
        }
        
        unstable {
            script {
                notifySlack(status: 'UNSTABLE', message: "Build is unstable. Check test results.")
            }
        }
    }
}
```

---

#### **STEP 19: Create Production Jenkinsfile**

**File:** `jenkins/Jenkinsfile.prod`

```groovy
// =============================================================================
// DevOps Testing App - Production Pipeline
// Triggered only for release branches and tags
// =============================================================================

@Library('devops-shared-library') _

pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "${env.DOCKER_HUB_USERNAME}/devops-testing-app"
        ENVIRONMENT = 'production'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timestamps()
        timeout(time: 90, unit: 'MINUTES')
    }
    
    stages {
        stage('Validate Release') {
            steps {
                script {
                    if (!env.TAG_NAME && env.BRANCH_NAME != 'main') {
                        error "Production pipeline requires a git tag or main branch"
                    }
                }
            }
        }
        
        stage('Run Full Test Suite') {
            steps {
                build job: 'devops-testing-app/main', 
                      wait: true,
                      propagate: true
            }
        }
        
        stage('Production Approval') {
            steps {
                input message: '''
                    Production Deployment Checklist:
                    ☑️ All tests passed
                    ☑️ Code review completed
                    ☑️ Release notes prepared
                    ☑️ Rollback plan ready
                    
                    Proceed with production deployment?
                ''',
                ok: 'Deploy to Production'
            }
        }
        
        stage('Deploy to Production') {
            steps {
                script {
                    def version = env.TAG_NAME ?: env.GIT_COMMIT_SHORT
                    
                    deployToAWS(
                        environment: 'production',
                        dockerImage: DOCKER_IMAGE,
                        dockerTag: version
                    )
                }
            }
        }
        
        stage('Smoke Tests') {
            steps {
                sh '''
                    # Wait for deployment to stabilize
                    sleep 30
                    
                    # Run smoke tests against production
                    ./scripts/health-check.sh ${PRODUCTION_URL} 80 10 10
                '''
            }
        }
        
        stage('Tag Release') {
            when {
                expression { return !env.TAG_NAME }
            }
            steps {
                script {
                    def version = "v${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )]) {
                        sh """
                            git tag -a ${version} -m "Release ${version}"
                            git push origin ${version}
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                notifySlack(
                    status: 'SUCCESS',
                    channel: '#releases',
                    message: "🚀 Production release successful!"
                )
            }
        }
        failure {
            script {
                // Auto-rollback on failure
                echo "Initiating automatic rollback..."
                
                deployToAWS(
                    environment: 'production',
                    dockerImage: DOCKER_IMAGE,
                    dockerTag: 'previous'
                )
                
                createJiraIssue(
                    projectKey: 'DEVOPS',
                    summary: "CRITICAL: Production deployment failed",
                    priority: 'Highest'
                )
            }
        }
    }
}
```

---

#### **STEP 20: Create Supporting Configuration Files**

**File:** `.env.example`

```bash
# =============================================================================
# DevOps Testing App - Environment Variables
# Copy to .env and fill in your values
# =============================================================================

# Flask Configuration
FLASK_APP=main.py
FLASK_ENV=development
FLASK_DEBUG=1
SECRET_KEY=your-secret-key-change-in-production

# Docker Hub Configuration
DOCKER_HUB_USERNAME=your-dockerhub-username
DOCKER_REGISTRY=docker.io

# AWS Configuration
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1

# JIRA Configuration (for Jenkins)
JIRA_URL=https://your-company.atlassian.net
JIRA_PROJECT_KEY=DEVOPS

# Slack Configuration (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx/yyy/zzz
```

**File:** `.gitignore`

```gitignore
# =============================================================================
# DevOps Testing App - Git Ignore
# =============================================================================

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
.venv/
ENV/
.eggs/
*.egg-info/
*.egg

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/

# IDE
.cursor/logs/
.cursor/wip/
.vscode/
.idea/
*.swp
*.swo
*~

# Environment
.env
.env.local
*.local

# Terraform
infrastructure/terraform/.terraform/
infrastructure/terraform/*.tfstate*
infrastructure/terraform/.terraform.lock.hcl
infrastructure/terraform/terraform.tfvars

# Ansible
infrastructure/ansible/*.retry

# Docker
docker-compose.override.yml

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Temp
tmp/
temp/
```

**File:** `tests/conftest.py`

```python
# =============================================================================
# DevOps Testing App - Shared Test Fixtures
# =============================================================================
import pytest
from app import create_app


@pytest.fixture(scope='session')
def app():
    """Create application for testing."""
    app = create_app()
    app.config.update({
        'TESTING': True,
        'DEBUG': False,
    })
    return app


@pytest.fixture(scope='session')
def client(app):
    """Create test client."""
    return app.test_client()


@pytest.fixture(scope='function')
def runner(app):
    """Create CLI runner."""
    return app.test_cli_runner()


@pytest.fixture
def sample_user():
    """Sample user data for tests."""
    return {
        'name': 'Test User',
        'email': 'test@example.com'
    }


@pytest.fixture
def sample_product():
    """Sample product data for tests."""
    return {
        'name': 'Test Product',
        'price': 99.99,
        'stock': 50
    }
```

---

## 6. Validation Checkpoints

### Checkpoint 1: Docker Setup ✓
```bash
cd /Users/danielmazmazhbits/CProjects/devops-ci-cd-exercise

# Build image
docker build -f docker/Dockerfile -t devops-app:test .

# Run container
docker run -d -p 5000:5000 --name test-app devops-app:test

# Test health
curl http://localhost:5000/health
# Expected: {"service":"devops-testing-app","status":"healthy"}

# Cleanup
docker stop test-app && docker rm test-app
```

### Checkpoint 2: Terraform Validation ✓
```bash
cd infrastructure/terraform
terraform init
terraform validate
terraform plan -var="key_name=test" -var="docker_image=test"
# Expected: Plan shows resources to create
```

### Checkpoint 3: Ansible Validation ✓
```bash
cd infrastructure/ansible
ansible-playbook --syntax-check playbooks/setup.yml
ansible-playbook --syntax-check playbooks/deploy.yml
ansible-playbook --syntax-check playbooks/rollback.yml
# Expected: All pass syntax check
```

### Checkpoint 4: All Tests Pass ✓
```bash
cd /Users/danielmazmazhbits/CProjects/devops-ci-cd-exercise
source venv/bin/activate
pytest tests/unit/ tests/integration/ -v
# Expected: All tests pass
```

### Checkpoint 5: Full Pipeline Dry Run ✓
```bash
# Validate Jenkinsfile syntax (requires Jenkins CLI)
# java -jar jenkins-cli.jar -s http://localhost:8080 declarative-linter < jenkins/Jenkinsfile
# Expected: Jenkinsfile successfully validated
```

---

## 7. Trade-offs & Decisions

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| Multi-stage Docker build | Smaller image (~150MB vs ~900MB) | Single-stage (simpler but larger) |
| Python 3.11-slim | Balance of features/size/security | Alpine (smaller but glibc issues) |
| Gunicorn workers=4 | Good default for t3.micro | uWSGI (more config complexity) |
| Terraform for IaC | Industry standard, declarative | CloudFormation (AWS-only) |
| Ansible for config | Agentless, YAML-based | Chef/Puppet (more complex) |
| Separate staging/prod pipelines | Clear separation of concerns | Single pipeline with conditions |

---

## 8. Verification Criteria

| # | Criteria | Verification Command |
|---|----------|---------------------|
| 1 | Docker image builds | `docker build -f docker/Dockerfile .` exits 0 |
| 2 | Container runs | `docker run` + health check returns 200 |
| 3 | All unit tests pass | `pytest tests/unit/ -v` shows 100% pass |
| 4 | All integration tests pass | `pytest tests/integration/ -v` shows 100% pass |
| 5 | Terraform validates | `terraform validate` exits 0 |
| 6 | Ansible syntax valid | `ansible-playbook --syntax-check` exits 0 |
| 7 | Coverage > 80% | `coverage report` shows >= 80% |
| 8 | No high/critical security issues | `bandit -r app/` shows no high severity |

---

## 9. Execution Checklist

- [ ] Phase 1: Docker Setup (Steps 1-5)
- [ ] Phase 2: Infrastructure as Code (Steps 6-15)
- [ ] Phase 3: Enhanced Jenkins Pipeline (Steps 16-20)
- [ ] All validation checkpoints passed
- [ ] Documentation screenshots captured

---

**End of Master Implementation Plan**
