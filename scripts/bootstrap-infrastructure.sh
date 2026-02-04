#!/usr/bin/env bash
# =============================================================================
# Bootstrap Infrastructure Script
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
#   - AWS CLI configured (~/.aws/credentials)
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

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
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
    1. AWS CLI configured with credentials
    2. Terraform >= 1.0.0 installed
    3. Ansible >= 2.9 installed
    4. SSH key file exists (path in terraform.tfvars)
    5. Environment variable for Docker Hub (required for docker push):
       export DOCKER_HUB_TOKEN='your-docker-hub-personal-access-token'

EOF
}

check_prerequisites() {
    log_step "Checking Prerequisites"
    
    local missing=()
    
    # Check required commands
    for cmd in terraform ansible-playbook aws jq; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        else
            log_success "$cmd found: $(command -v $cmd)"
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        missing+=("aws-credentials")
    else
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        log_success "AWS credentials valid (Account: $account_id)"
    fi
    
    # Check terraform.tfvars exists
    if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        log_error "terraform.tfvars not found at $TERRAFORM_DIR/terraform.tfvars"
        missing+=("terraform.tfvars")
    else
        log_success "terraform.tfvars found"
    fi
    
    # Check SSH key
    local ssh_key_path=$(grep -E "^ssh_key_path" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | cut -d'"' -f2 || echo "")
    ssh_key_path=$(eval echo "$ssh_key_path")  # Expand ~ if present
    if [[ -n "$ssh_key_path" && -f "$ssh_key_path" ]]; then
        log_success "SSH key found: $ssh_key_path"
    else
        log_warning "SSH key not found or not specified"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing prerequisites: ${missing[*]}"
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
    log_info "Applying infrastructure..."
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
        
        log_success "Jenkins IP: $JENKINS_IP"
        log_success "App IP: $APP_IP"
    fi
    
    cd "$PROJECT_ROOT"
}

create_ansible_inventory() {
    log_step "Creating Ansible Dynamic Inventory"
    
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
    
    # Create staging inventory
    cat > "$ANSIBLE_DIR/inventory/staging.ini" << EOF
# Auto-generated by bootstrap script
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

[jenkins]
jenkins-server ansible_host=$JENKINS_IP

[app]
app-server ansible_host=$APP_IP

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file={{ lookup('env', 'SSH_KEY_PATH') | default('~/.ssh/daniel-devops.pem', true) }}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
    
    log_success "Created inventory at $ANSIBLE_DIR/inventory/staging.ini"
}

wait_for_instances() {
    log_step "Waiting for EC2 Instances to be Ready"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would wait for instances"
        return
    fi
    
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for SSH connectivity (this may take 1-2 minutes)..."
    
    for ip in $JENKINS_IP $APP_IP; do
        log_info "Checking $ip..."
        attempt=1
        while [[ $attempt -le $max_attempts ]]; do
            if nc -z -w5 "$ip" 22 2>/dev/null; then
                log_success "$ip is reachable on port 22"
                break
            fi
            log_info "Attempt $attempt/$max_attempts - waiting for $ip..."
            sleep 10
            ((attempt++))
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "Timeout waiting for $ip"
            exit 1
        fi
    done
    
    # Extra wait for cloud-init to complete
    log_info "Waiting 30 seconds for cloud-init to complete..."
    sleep 30
}

run_ansible() {
    log_step "Running Ansible Configuration"
    
    cd "$ANSIBLE_DIR"
    
    # Get SSH key path
    local ssh_key_path=$(grep -E "^ssh_key_path" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | cut -d'"' -f2 || echo "~/.ssh/daniel-devops.pem")
    ssh_key_path=$(eval echo "$ssh_key_path")
    
    export ANSIBLE_HOST_KEY_CHECKING=False
    export SSH_KEY_PATH="$ssh_key_path"
    
    # Get Docker Hub token from environment or prompt
    local docker_hub_token="${DOCKER_HUB_TOKEN:-}"
    if [[ -z "$docker_hub_token" ]]; then
        log_warning "DOCKER_HUB_TOKEN not set. Docker push will fail in Jenkins."
        log_info "Set it with: export DOCKER_HUB_TOKEN='your-token'"
    fi
    
    # Setup Jenkins
    log_info "Setting up Jenkins server..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: ansible-playbook playbooks/jenkins-setup.yml"
    else
        ansible-playbook playbooks/jenkins-setup.yml \
            -i inventory/staging.ini \
            --private-key="$ssh_key_path" \
            -e "ansible_ssh_private_key_file=$ssh_key_path" \
            -e "docker_hub_token=${docker_hub_token}" \
            -e "app_server_ip=$APP_IP"
    fi
    
    # Setup App server
    log_info "Setting up App server..."
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: ansible-playbook playbooks/app-setup.yml"
    else
        ansible-playbook playbooks/app-setup.yml \
            -i inventory/staging.ini \
            --private-key="$ssh_key_path" \
            -e "ansible_ssh_private_key_file=$ssh_key_path" \
            -e "docker_hub_token=${docker_hub_token}"
    fi
    
    cd "$PROJECT_ROOT"
    log_success "Ansible configuration complete!"
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
    local jenkins_attempts=0
    while [[ $jenkins_attempts -lt 10 ]]; do
        if curl -sf "http://$JENKINS_IP:8080/login" > /dev/null 2>&1; then
            log_success "Jenkins is accessible!"
            break
        fi
        log_info "Waiting for Jenkins to start... (attempt $((jenkins_attempts+1))/10)"
        sleep 30
        ((jenkins_attempts++))
    done
    
    if [[ $jenkins_attempts -ge 10 ]]; then
        log_warning "Jenkins may not be ready yet. Check manually at http://$JENKINS_IP:8080"
        all_healthy=false
    fi
    
    # Check App (if deployed)
    log_info "Checking App at http://$APP_IP..."
    if curl -sf "http://$APP_IP/health" > /dev/null 2>&1; then
        log_success "App is healthy!"
    else
        log_warning "App not yet deployed or not healthy (this is expected on first run)"
    fi
    
    return 0
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

  🔑 To get Jenkins initial admin password:
     ./scripts/get-jenkins-password.sh

  🔗 SSH Commands:
     Jenkins: ssh -i ~/.ssh/daniel-devops.pem ec2-user@${JENKINS_IP}
     App:     ssh -i ~/.ssh/daniel-devops.pem ec2-user@${APP_IP}

  📋 Next Steps:
     1. Access Jenkins at http://${JENKINS_IP}:8080
     2. Login with admin credentials (use get-jenkins-password.sh)
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
    else
        log_info "Skipping Ansible (--skip-ansible)"
    fi
    
    # Health checks
    run_health_checks
    
    # Print summary
    print_summary
    
    log_success "Bootstrap complete!"
}

# Run main
main "$@"
