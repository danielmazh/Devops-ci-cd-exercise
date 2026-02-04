#!/usr/bin/env bash
# =============================================================================
# Get Jenkins Admin Password Script
# =============================================================================
# Retrieves the initial admin password from the Jenkins server
#
# Usage:
#   ./get-jenkins-password.sh [OPTIONS]
#
# Options:
#   --jenkins-ip IP  Jenkins server IP (auto-detected from Terraform)
#   --ssh-key PATH   Path to SSH private key
#   --help           Show this help message
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"

# Defaults
JENKINS_IP=""
SSH_KEY=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                      Get Jenkins Admin Password                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --jenkins-ip IP   Jenkins server IP (auto-detected from Terraform if not set)
    --ssh-key PATH    Path to SSH private key (auto-detected from terraform.tfvars)
    --help            Show this help message

EXAMPLES:
    # Auto-detect everything
    ./$(basename "$0")
    
    # Specify Jenkins IP
    ./$(basename "$0") --jenkins-ip 1.2.3.4
    
    # Specify SSH key
    ./$(basename "$0") --ssh-key ~/.ssh/my-key.pem

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --jenkins-ip)
            JENKINS_IP="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
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

# Get Jenkins IP from Terraform if not provided
if [[ -z "$JENKINS_IP" ]]; then
    log_info "Getting Jenkins IP from Terraform..."
    
    cd "$TERRAFORM_DIR"
    JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
    cd "$PROJECT_ROOT"
    
    if [[ -z "$JENKINS_IP" ]]; then
        log_error "Could not determine Jenkins IP. Use --jenkins-ip or run terraform apply first."
        exit 1
    fi
fi

# Get SSH key path from terraform.tfvars if not provided
if [[ -z "$SSH_KEY" ]]; then
    SSH_KEY=$(grep -E "^ssh_key_path" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | cut -d'"' -f2 || echo "")
    SSH_KEY=$(eval echo "$SSH_KEY")  # Expand ~
    
    if [[ -z "$SSH_KEY" ]] || [[ ! -f "$SSH_KEY" ]]; then
        # Try common locations
        for key in ~/.ssh/daniel-devops.pem ~/keys/daniel-devops.pem; do
            key=$(eval echo "$key")
            if [[ -f "$key" ]]; then
                SSH_KEY="$key"
                break
            fi
        done
    fi
    
    if [[ -z "$SSH_KEY" ]] || [[ ! -f "$SSH_KEY" ]]; then
        log_error "Could not find SSH key. Use --ssh-key to specify path."
        exit 1
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                      Jenkins Admin Password Retrieval                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Jenkins IP: $JENKINS_IP"
log_info "SSH Key:    $SSH_KEY"
echo ""

# Check SSH connectivity first
log_info "Testing SSH connectivity..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 ec2-user@"$JENKINS_IP" "echo connected" &>/dev/null; then
    log_error "Cannot connect to Jenkins server via SSH"
    echo ""
    echo "  Troubleshooting:"
    echo "    - Check if instance is running"
    echo "    - Verify security group allows SSH (port 22)"
    echo "    - Ensure correct SSH key is being used"
    echo ""
    exit 1
fi

log_success "SSH connection successful!"
echo ""

# Method 1: Try to get from Docker container
log_info "Retrieving Jenkins admin password..."
echo ""

PASSWORD=""

# Try Docker container method
PASSWORD=$(ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ec2-user@"$JENKINS_IP" \
    "sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null" 2>/dev/null || echo "")

if [[ -z "$PASSWORD" ]]; then
    # Try direct file access (if Jenkins is running directly)
    PASSWORD=$(ssh -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        ec2-user@"$JENKINS_IP" \
        "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" 2>/dev/null || echo "")
fi

if [[ -z "$PASSWORD" ]]; then
    log_warning "Could not retrieve initial admin password."
    echo ""
    echo "  This might mean:"
    echo "    - Jenkins hasn't finished initializing (wait a few minutes)"
    echo "    - Jenkins was already configured (password was changed)"
    echo "    - Jenkins is using Configuration as Code (CasC)"
    echo ""
    echo "  If using CasC, the credentials are:"
    echo "    Username: admin"
    echo "    Password: (set via JENKINS_ADMIN_PASSWORD environment variable)"
    echo ""
    echo "  Try accessing: http://$JENKINS_IP:8080"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Jenkins Admin Credentials                            ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${CYAN}Jenkins URL:${NC}  http://$JENKINS_IP:8080"
echo ""
echo -e "  ${CYAN}Username:${NC}     admin"
echo -e "  ${CYAN}Password:${NC}     ${GREEN}$PASSWORD${NC}"
echo ""
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

# Copy to clipboard if available
if command -v pbcopy &> /dev/null; then
    echo -n "$PASSWORD" | pbcopy
    log_success "Password copied to clipboard!"
elif command -v xclip &> /dev/null; then
    echo -n "$PASSWORD" | xclip -selection clipboard
    log_success "Password copied to clipboard!"
fi

echo ""
log_info "After initial login, you can change the password in Jenkins settings."
echo ""
