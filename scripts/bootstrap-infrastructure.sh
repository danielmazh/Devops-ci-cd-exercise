#!/usr/bin/env bash
# =============================================================================
# Bootstrap Infrastructure Script - PRODUCTION READY
# =============================================================================
# Single-command deployment for the entire DevOps CI/CD infrastructure
# 
# Usage:
#   ./bootstrap-infrastructure.sh [OPTIONS]
#
# Options:
#   --dry-run       Show what would be done without executing
#   --skip-terraform Skip Terraform provisioning (use existing infra)
#   --skip-ansible   Skip Ansible configuration
#   --destroy        Destroy infrastructure instead of creating
#   --help           Show this help message
#
# Prerequisites:
#   - AWS CLI configured (~/.aws/credentials) OR .env file with credentials
#   - Terraform installed
#   - Ansible installed
#   - SSH key at path specified in terraform.tfvars
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/infrastructure/ansible"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
DRY_RUN=false
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false
DESTROY=false

# Timeouts
INSTANCE_READY_TIMEOUT=300
JENKINS_START_TIMEOUT=600
SSH_TIMEOUT=30

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"
}

log_step() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Run command with timeout
run_with_timeout() {
    local timeout=$1
    shift
    timeout $timeout "$@"
    return $?
}

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                    DevOps CI/CD Infrastructure Bootstrap                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --dry-run         Show what would be done without executing
    --skip-terraform  Skip Terraform provisioning (use existing infrastructure)
    --skip-ansible    Skip Ansible configuration
    --destroy         Destroy infrastructure instead of creating
    --help            Show this help message

EXAMPLES:
    # Full deployment
    ./$(basename "$0")
    
    # Preview changes
    ./$(basename "$0") --dry-run
    
    # Only run Ansible (infra already exists)
    ./$(basename "$0") --skip-terraform
    
    # Destroy everything
    ./$(basename "$0") --destroy

PREREQUISITES:
    1. AWS CLI configured OR credentials in .env file
    2. Terraform >= 1.0.0 installed
    3. Ansible >= 2.9 installed
    4. SSH key file exists (path in terraform.tfvars)

ENVIRONMENT FILE (.env):
    If you prefer, create a .env file in the project root with:
        AWS_ACCESS_KEY_ID=your-access-key
        AWS_SECRET_ACCESS_KEY=your-secret-key
        AWS_REGION=us-east-1
        DOCKER_HUB_TOKEN=your-docker-token
        GITHUB_TOKEN=your-github-token (optional)
        JIRA_API_TOKEN=your-jira-token (optional)

EOF
}

load_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading credentials from .env file..."
        set -a
        source "$ENV_FILE"
        set +a
        log_success "Loaded .env file"
    fi
}

load_credentials_from_tfvars() {
    log_info "Loading credentials from terraform.tfvars..."
    
    local tfvars="$TERRAFORM_DIR/terraform.tfvars"
    if [[ ! -f "$tfvars" ]]; then
        log_error "terraform.tfvars not found!"
        return 1
    fi
    
    # Export AWS credentials
    export AWS_ACCESS_KEY_ID=$(grep -E "^aws_access_key\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export AWS_SECRET_ACCESS_KEY=$(grep -E "^aws_secret_key\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export AWS_DEFAULT_REGION=$(grep -E "^aws_region\s*=" "$tfvars" | cut -d'"' -f2 || echo "us-east-1")
    
    # Export Docker Hub credentials
    export DOCKER_HUB_USERNAME=$(grep -E "^docker_hub_username\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export DOCKER_HUB_TOKEN=$(grep -E "^docker_hub_token\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    
    # Export GitHub credentials
    export GITHUB_USERNAME=$(grep -E "^github_username\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export GITHUB_TOKEN=$(grep -E "^github_token\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export GITHUB_REPO=$(grep -E "^github_repo\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    
    # Export JIRA credentials
    export JIRA_URL=$(grep -E "^jira_url\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export JIRA_EMAIL=$(grep -E "^jira_email\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export JIRA_API_TOKEN=$(grep -E "^jira_api_token\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export JIRA_PROJECT_KEY=$(grep -E "^jira_project_key\s*=" "$tfvars" | cut -d'"' -f2 || echo "CICD")
    
    # Export Jenkins credentials
    export JENKINS_ADMIN_USER=$(grep -E "^jenkins_admin_user\s*=" "$tfvars" | cut -d'"' -f2 || echo "admin")
    export JENKINS_ADMIN_PASSWORD=$(grep -E "^jenkins_admin_password\s*=" "$tfvars" | cut -d'"' -f2 || echo "DevOps2026!")
    
    # Export SSH key path (note: it's ssh_private_key_path in tfvars)
    export SSH_KEY_PATH=$(grep -E "^ssh_private_key_path\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    
    # Export notification email
    export NOTIFICATION_EMAIL=$(grep -E "^owner_email\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    
    # Export SMTP/Email credentials
    export SMTP_HOST=$(grep -E "^smtp_host\s*=" "$tfvars" | cut -d'"' -f2 || echo "smtp.gmail.com")
    export SMTP_PORT=$(grep -E "^smtp_port\s*=" "$tfvars" | cut -d'"' -f2 || echo "587")
    export SMTP_USERNAME=$(grep -E "^smtp_username\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    export SMTP_PASSWORD=$(grep -E "^smtp_password\s*=" "$tfvars" | cut -d'"' -f2 || echo "")
    
    log_success "Loaded credentials from terraform.tfvars"
}

load_credentials_from_parameter_store() {
    log_info "Checking for credentials in AWS Parameter Store..."
    
    # Try to get a parameter - if it exists, Parameter Store is set up
    local test_param=$(aws ssm get-parameter --name "/devops/docker_hub_token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    if [[ -z "$test_param" ]]; then
        log_info "No credentials found in Parameter Store (using tfvars instead)"
        return 1
    fi
    
    log_success "Found credentials in Parameter Store - loading..."
    
    # Load all credentials from Parameter Store
    export DOCKER_HUB_USERNAME=$(aws ssm get-parameter --name "/devops/docker_hub_username" --query 'Parameter.Value' --output text 2>/dev/null || echo "$DOCKER_HUB_USERNAME")
    export DOCKER_HUB_TOKEN=$(aws ssm get-parameter --name "/devops/docker_hub_token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$DOCKER_HUB_TOKEN")
    export GITHUB_USERNAME=$(aws ssm get-parameter --name "/devops/github_username" --query 'Parameter.Value' --output text 2>/dev/null || echo "$GITHUB_USERNAME")
    export GITHUB_TOKEN=$(aws ssm get-parameter --name "/devops/github_token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$GITHUB_TOKEN")
    export JIRA_URL=$(aws ssm get-parameter --name "/devops/jira_url" --query 'Parameter.Value' --output text 2>/dev/null || echo "$JIRA_URL")
    export JIRA_EMAIL=$(aws ssm get-parameter --name "/devops/jira_email" --query 'Parameter.Value' --output text 2>/dev/null || echo "$JIRA_EMAIL")
    export JIRA_API_TOKEN=$(aws ssm get-parameter --name "/devops/jira_api_token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$JIRA_API_TOKEN")
    export JENKINS_ADMIN_PASSWORD=$(aws ssm get-parameter --name "/devops/jenkins_password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$JENKINS_ADMIN_PASSWORD")
    export SSH_KEY_PATH=$(aws ssm get-parameter --name "/devops/ssh_key_path" --query 'Parameter.Value' --output text 2>/dev/null || echo "$SSH_KEY_PATH")
    
    # Load SSH private key content (base64 encoded) for Jenkins credential
    export SSH_PRIVATE_KEY_B64=$(aws ssm get-parameter --name "/devops/ssh_private_key" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    # Load SMTP/Email credentials
    export SMTP_HOST=$(aws ssm get-parameter --name "/devops/smtp_host" --query 'Parameter.Value' --output text 2>/dev/null || echo "$SMTP_HOST")
    export SMTP_PORT=$(aws ssm get-parameter --name "/devops/smtp_port" --query 'Parameter.Value' --output text 2>/dev/null || echo "$SMTP_PORT")
    export SMTP_USERNAME=$(aws ssm get-parameter --name "/devops/smtp_username" --query 'Parameter.Value' --output text 2>/dev/null || echo "$SMTP_USERNAME")
    export SMTP_PASSWORD=$(aws ssm get-parameter --name "/devops/smtp_password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "$SMTP_PASSWORD")
    
    log_success "Loaded credentials from Parameter Store"
    return 0
}

check_prerequisites() {
    log_step "Checking Prerequisites"
    
    local missing=()
    
    # Check required commands
    for cmd in terraform ansible-playbook jq nc curl; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        else
            log_success "$cmd found: $(command -v $cmd)"
        fi
    done
    
    # Load credentials from .env file first, then tfvars
    load_env_file
    load_credentials_from_tfvars
    
    # Try to load from Parameter Store (will use tfvars values as fallback)
    load_credentials_from_parameter_store || true
    
    # Check AWS credentials
    if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        log_error "AWS credentials not found in .env or terraform.tfvars"
        missing+=("aws-credentials")
    else
        # Verify AWS credentials work
        if aws sts get-caller-identity &> /dev/null; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            log_success "AWS credentials valid (Account: $account_id)"
        else
            log_error "AWS credentials invalid"
            missing+=("aws-credentials")
        fi
    fi
    
    # Check terraform.tfvars exists
    if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        log_error "terraform.tfvars not found at $TERRAFORM_DIR/terraform.tfvars"
        missing+=("terraform.tfvars")
    else
        log_success "terraform.tfvars found"
    fi
    
    # Check SSH key (using ssh_private_key_path from tfvars)
    local ssh_key_path="$SSH_KEY_PATH"
    ssh_key_path=$(eval echo "$ssh_key_path")  # Expand ~ if present
    
    if [[ -n "$ssh_key_path" && -f "$ssh_key_path" ]]; then
        log_success "SSH key found: $ssh_key_path"
        export SSH_KEY_PATH="$ssh_key_path"
    else
        log_error "SSH key not found at: $ssh_key_path"
        missing+=("ssh-key")
    fi
    
    # Check Docker Hub token
    if [[ -z "$DOCKER_HUB_TOKEN" ]]; then
        log_warning "DOCKER_HUB_TOKEN not set. Docker push will fail in Jenkins."
    else
        log_success "Docker Hub token configured"
    fi
    
    # Check SMTP credentials for email notifications
    if [[ -z "$SMTP_USERNAME" || -z "$SMTP_PASSWORD" ]]; then
        log_warning "SMTP credentials not set. Email notifications will NOT work."
        log_warning "Add smtp_username and smtp_password to terraform.tfvars"
        log_warning "For Gmail: Use App Password from https://myaccount.google.com/apppasswords"
    else
        log_success "SMTP credentials configured (${SMTP_HOST}:${SMTP_PORT})"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing prerequisites: ${missing[*]}"
        echo ""
        echo "Please ensure all prerequisites are met before running this script."
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

run_terraform() {
    log_step "Running Terraform"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize
    log_info "Initializing Terraform..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: terraform init"
    else
        terraform init -upgrade
    fi
    
    # Plan
    log_info "Planning infrastructure..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: terraform plan"
    else
        terraform plan -out=tfplan
    fi
    
    # Apply
    log_info "Applying infrastructure (this may take 3-5 minutes)..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: terraform apply tfplan"
    else
        terraform apply tfplan
        rm -f tfplan
    fi
    
    # Get outputs
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Terraform outputs:"
        terraform output
        
        # Export IPs for Ansible
        export JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
        export APP_IP=$(terraform output -raw app_public_ip 2>/dev/null || echo "")
        
        if [[ -z "$JENKINS_IP" || -z "$APP_IP" ]]; then
            log_error "Failed to get IPs from Terraform outputs"
            exit 1
        fi
        
        log_success "Jenkins IP: $JENKINS_IP"
        log_success "App IP: $APP_IP"
    fi
    
    cd "$PROJECT_ROOT"
}

create_ansible_inventory() {
    log_step "Creating Ansible Inventory"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would create dynamic inventory"
        return
    fi
    
    # Get IPs from Terraform if not already set
    cd "$TERRAFORM_DIR"
    JENKINS_IP=${JENKINS_IP:-$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")}
    APP_IP=${APP_IP:-$(terraform output -raw app_public_ip 2>/dev/null || echo "")}
    cd "$PROJECT_ROOT"
    
    if [[ -z "$JENKINS_IP" || -z "$APP_IP" ]]; then
        log_error "Could not get IPs from Terraform outputs"
        exit 1
    fi
    
    # Create staging inventory with HARDCODED SSH key path (not Jinja2)
    cat > "$ANSIBLE_DIR/inventory/staging.ini" << EOF
# Auto-generated by bootstrap script
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

[jenkins]
jenkins-server ansible_host=$JENKINS_IP

[app]
app-server ansible_host=$APP_IP

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=$SSH_KEY_PATH
ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30
EOF
    
    log_success "Created inventory at $ANSIBLE_DIR/inventory/staging.ini"
    cat "$ANSIBLE_DIR/inventory/staging.ini"
}

wait_for_instances() {
    log_step "Waiting for EC2 Instances to be Ready"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would wait for instances"
        return
    fi
    
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for SSH connectivity (timeout: ${INSTANCE_READY_TIMEOUT}s)..."
    
    for ip in $JENKINS_IP $APP_IP; do
        log_info "Checking $ip..."
        attempt=1
        local start_time=$(date +%s)
        
        while [[ $attempt -le $max_attempts ]]; do
            if nc -z -w5 "$ip" 22 2>/dev/null; then
                log_success "$ip is reachable on port 22"
                break
            fi
            
            local elapsed=$(($(date +%s) - start_time))
            if [[ $elapsed -gt $INSTANCE_READY_TIMEOUT ]]; then
                log_error "Timeout waiting for $ip after ${elapsed}s"
                exit 1
            fi
            
            log_info "Attempt $attempt/$max_attempts - waiting for $ip... (${elapsed}s elapsed)"
            sleep 10
            ((attempt++))
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "Max attempts reached waiting for $ip"
            exit 1
        fi
    done
    
    # Extra wait for cloud-init to complete
    log_info "Waiting 45 seconds for cloud-init to complete..."
    sleep 45
    log_success "All instances ready!"
}

run_ansible() {
    log_step "Running Ansible Configuration"
    
    cd "$ANSIBLE_DIR"
    
    export ANSIBLE_HOST_KEY_CHECKING=False
    
    # Create JSON file with extra vars (handles spaces in values like SMTP password) (handles spaces in values)
    local extra_vars_file="/tmp/ansible-extra-vars.json"
    cat > "$extra_vars_file" << EXTRAVARS_EOF
{
    "ansible_ssh_private_key_file": "$SSH_KEY_PATH",
    "docker_hub_username": "$DOCKER_HUB_USERNAME",
    "docker_hub_token": "$DOCKER_HUB_TOKEN",
    "github_username": "$GITHUB_USERNAME",
    "github_token": "$GITHUB_TOKEN",
    "github_repo": "$GITHUB_REPO",
    "jira_url": "$JIRA_URL",
    "jira_email": "$JIRA_EMAIL",
    "jira_api_token": "$JIRA_API_TOKEN",
    "jira_project_key": "$JIRA_PROJECT_KEY",
    "jenkins_admin_user": "$JENKINS_ADMIN_USER",
    "jenkins_admin_password": "$JENKINS_ADMIN_PASSWORD",
    "notification_email": "$NOTIFICATION_EMAIL",
    "app_server_ip": "$APP_IP",
    "aws_access_key": "$AWS_ACCESS_KEY_ID",
    "aws_secret_key": "$AWS_SECRET_ACCESS_KEY",
    "aws_region": "$AWS_DEFAULT_REGION",
    "smtp_host": "$SMTP_HOST",
    "smtp_port": "$SMTP_PORT",
    "smtp_username": "$SMTP_USERNAME",
    "smtp_password": "$SMTP_PASSWORD",
    "ssh_private_key_b64": "$SSH_PRIVATE_KEY_B64"
}
EXTRAVARS_EOF
    
    # Setup Jenkins
    log_info "Setting up Jenkins server (this may take 5-10 minutes)..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: ansible-playbook playbooks/jenkins-setup.yml"
    else
        local jenkins_start=$(date +%s)
        
        ansible-playbook playbooks/jenkins-setup.yml \
            -i inventory/staging.ini \
            --private-key="$SSH_KEY_PATH" \
            -e "@$extra_vars_file" \
            -v 2>&1 | tee /tmp/ansible-jenkins.log
        
        local jenkins_result=$?
        local jenkins_elapsed=$(($(date +%s) - jenkins_start))
        
        if [[ $jenkins_result -ne 0 ]]; then
            log_error "Jenkins setup failed after ${jenkins_elapsed}s!"
            log_error "Check logs at /tmp/ansible-jenkins.log"
            tail -50 /tmp/ansible-jenkins.log
            exit 1
        fi
        
        log_success "Jenkins setup completed in ${jenkins_elapsed}s"
    fi
    
    # Setup App server
    log_info "Setting up App server..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: ansible-playbook playbooks/app-setup.yml"
    else
        ansible-playbook playbooks/app-setup.yml \
            -i inventory/staging.ini \
            --private-key="$SSH_KEY_PATH" \
            -e "@$extra_vars_file" \
            -v 2>&1 | tee /tmp/ansible-app.log
        
        if [[ $? -ne 0 ]]; then
            log_error "App setup failed! Check logs at /tmp/ansible-app.log"
            tail -50 /tmp/ansible-app.log
            exit 1
        fi
        
        log_success "App setup completed"
    fi
    
    cd "$PROJECT_ROOT"
}

wait_for_jenkins() {
    log_step "Waiting for Jenkins to be Fully Ready"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would wait for Jenkins"
        return
    fi
    
    local start_time=$(date +%s)
    local max_wait=$JENKINS_START_TIMEOUT
    
    log_info "Waiting for Jenkins to be accessible (timeout: ${max_wait}s)..."
    
    while true; do
        local elapsed=$(($(date +%s) - start_time))
        
        if [[ $elapsed -gt $max_wait ]]; then
            log_error "Timeout waiting for Jenkins after ${elapsed}s"
            log_info "Checking Jenkins container logs..."
            ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$JENKINS_IP \
                "docker logs jenkins 2>&1 | tail -30" || true
            exit 1
        fi
        
        if curl -sf "http://$JENKINS_IP:8080/login" > /dev/null 2>&1; then
            log_success "Jenkins is accessible at http://$JENKINS_IP:8080"
            break
        fi
        
        log_info "Waiting for Jenkins... (${elapsed}s elapsed)"
        sleep 15
    done
}

install_jenkins_plugins() {
    log_step "Ensuring Jenkins Plugins are Installed"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install Jenkins plugins"
        return
    fi
    
    log_info "Installing critical Jenkins plugins via jenkins-plugin-cli..."
    
    # Wait a bit for Jenkins to fully initialize
    sleep 30
    
    # Install plugins using jenkins-plugin-cli (more reliable than jenkins-cli.jar)
    # This uses the built-in plugin installer that handles dependencies automatically
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$JENKINS_IP << 'ENDSSH'
echo "Installing Jenkins plugins with jenkins-plugin-cli..."

# Core framework plugins (order matters - dependencies first)
docker exec jenkins jenkins-plugin-cli --plugins \
    structs \
    workflow-step-api \
    workflow-api \
    workflow-support \
    scm-api \
    workflow-scm-step \
    workflow-job \
    workflow-cps \
    workflow-aggregator \
    pipeline-model-definition \
    pipeline-model-api \
    pipeline-model-extensions \
    pipeline-groovy-lib \
    pipeline-stage-view \
    pipeline-utility-steps \
    git \
    git-client \
    github \
    docker-workflow \
    credentials-binding \
    junit \
    htmlpublisher \
    email-ext \
    configuration-as-code \
    job-dsl \
    ws-cleanup \
    timestamper \
    ansicolor \
    http_request \
    ssh-agent \
    ssh-credentials

echo "Plugins installed. Restarting Jenkins to activate..."
docker restart jenkins
ENDSSH
    
    log_info "Waiting for Jenkins restart (90s)..."
    sleep 90
    
    # Wait for Jenkins to be ready again
    wait_for_jenkins
    
    log_success "Jenkins plugins installed and ready"
}

run_health_checks() {
    log_step "Running Health Checks"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run health checks"
        return
    fi
    
    local all_healthy=true
    
    # Check Jenkins
    log_info "Checking Jenkins at http://$JENKINS_IP:8080..."
    if curl -sf "http://$JENKINS_IP:8080/login" > /dev/null 2>&1; then
        log_success "Jenkins is accessible!"
        
        # Check if job exists
        if curl -sf -u "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASSWORD" \
            "http://$JENKINS_IP:8080/job/devops-testing-app/api/json" > /dev/null 2>&1; then
            log_success "Pipeline job 'devops-testing-app' exists!"
        else
            log_warning "Pipeline job may need manual reload (check Jenkins UI)"
        fi
    else
        log_warning "Jenkins may not be ready yet"
        all_healthy=false
    fi
    
    # Check App server Docker
    log_info "Checking App server at $APP_IP..."
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$APP_IP "docker --version" &>/dev/null; then
        log_success "App server Docker is ready!"
    else
        log_warning "App server Docker not ready"
        all_healthy=false
    fi
    
    return 0
}

trigger_first_build() {
    log_step "Triggering First Jenkins Build"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would trigger first build"
        return
    fi
    
    log_info "Triggering initial pipeline build..."
    
    # Get crumb and trigger build
    local crumb_response=$(curl -s -u "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASSWORD" \
        -c /tmp/jenkins-cookies.txt \
        "http://$JENKINS_IP:8080/crumbIssuer/api/json")
    
    local crumb=$(echo "$crumb_response" | jq -r '.crumb' 2>/dev/null || echo "")
    
    if [[ -n "$crumb" && "$crumb" != "null" ]]; then
        curl -s -X POST \
            -u "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASSWORD" \
            -b /tmp/jenkins-cookies.txt \
            -H "Jenkins-Crumb:$crumb" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            "http://$JENKINS_IP:8080/job/devops-testing-app/buildWithParameters" \
            -d "" 2>/dev/null
        
        log_success "Build triggered! Check Jenkins UI for progress."
    else
        log_warning "Could not trigger build automatically. Please trigger manually from Jenkins UI."
    fi
    
    rm -f /tmp/jenkins-cookies.txt
}

print_summary() {
    log_step "Deployment Summary"
    
    cd "$TERRAFORM_DIR"
    JENKINS_IP=${JENKINS_IP:-$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "N/A")}
    APP_IP=${APP_IP:-$(terraform output -raw app_public_ip 2>/dev/null || echo "N/A")}
    cd "$PROJECT_ROOT"
    
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                         🎉 DEPLOYMENT COMPLETE! 🎉                            ║
╚══════════════════════════════════════════════════════════════════════════════╝

  📍 Jenkins URL:     http://${JENKINS_IP}:8080
  📍 App URL:         http://${APP_IP}
  📍 App Health:      http://${APP_IP}/health

  🔑 Jenkins Credentials:
     Username: ${JENKINS_ADMIN_USER:-admin}
     Password: ${JENKINS_ADMIN_PASSWORD:-DevOps2026!}

  🔗 SSH Commands:
     Jenkins: ssh -i $SSH_KEY_PATH ec2-user@${JENKINS_IP}
     App:     ssh -i $SSH_KEY_PATH ec2-user@${APP_IP}

  📋 Next Steps:
     1. Access Jenkins at http://${JENKINS_IP}:8080
     2. Login with admin credentials
     3. Run the 'devops-testing-app' pipeline
     4. Monitor deployment at http://${APP_IP}

  💡 To destroy infrastructure:
     ./scripts/destroy-infrastructure.sh

══════════════════════════════════════════════════════════════════════════════

EOF
}

destroy_infrastructure() {
    log_step "Destroying Infrastructure"
    
    cd "$TERRAFORM_DIR"
    
    log_warning "This will DESTROY all infrastructure!"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: terraform destroy"
        terraform plan -destroy
    else
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [[ "$confirm" == "yes" ]]; then
            terraform destroy -auto-approve
            log_success "Infrastructure destroyed!"
        else
            log_info "Destruction cancelled."
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_warning "Running in DRY-RUN mode"
                shift
                ;;
            --skip-terraform)
                SKIP_TERRAFORM=true
                shift
                ;;
            --skip-ansible)
                SKIP_ANSIBLE=true
                shift
                ;;
            --destroy)
                DESTROY=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    DevOps CI/CD Infrastructure Bootstrap                      ║"
    echo "║                              $(date +"%Y-%m-%d %H:%M:%S")                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    local start_time=$(date +%s)
    
    # Run prerequisite checks
    check_prerequisites
    
    if [[ "$DESTROY" == true ]]; then
        destroy_infrastructure
        exit 0
    fi
    
    # Run Terraform
    if [[ "$SKIP_TERRAFORM" != true ]]; then
        run_terraform
    else
        log_info "Skipping Terraform (--skip-terraform)"
        # Still need to get IPs
        cd "$TERRAFORM_DIR"
        export JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
        export APP_IP=$(terraform output -raw app_public_ip 2>/dev/null || echo "")
        cd "$PROJECT_ROOT"
    fi
    
    # Create inventory and wait for instances
    if [[ "$SKIP_ANSIBLE" != true ]]; then
        create_ansible_inventory
        wait_for_instances
        run_ansible
        wait_for_jenkins
        install_jenkins_plugins
    else
        log_info "Skipping Ansible (--skip-ansible)"
    fi
    
    # Health checks
    run_health_checks
    
    # Optionally trigger first build
    # trigger_first_build
    
    # Print summary
    print_summary
    
    local total_time=$(($(date +%s) - start_time))
    log_success "Bootstrap complete in ${total_time}s!"
}

# Run main
main "$@"
