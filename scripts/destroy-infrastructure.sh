#!/usr/bin/env bash
# =============================================================================
# Destroy Infrastructure Script - COMPLETE CLEANUP
# =============================================================================
# Safely tears down ALL AWS infrastructure created by Terraform
# Ensures no orphaned resources are left behind
#
# Usage:
#   ./destroy-infrastructure.sh [OPTIONS]
#
# Options:
#   --force    Skip confirmation prompt
#   --dry-run  Show what would be destroyed without executing
#   --cleanup  Clean up orphaned resources not in state file
#   --help     Show this help message
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Options
FORCE=false
DRY_RUN=false
CLEANUP=false

log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                      Infrastructure Destruction Script                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --force     Skip confirmation prompt (DANGEROUS!)
    --dry-run   Show what would be destroyed without executing
    --cleanup   Also clean up orphaned AWS resources not in Terraform state
    --help      Show this help message

EXAMPLES:
    # Interactive destruction (with confirmation)
    ./$(basename "$0")
    
    # Preview what would be destroyed
    ./$(basename "$0") --dry-run
    
    # Force destroy without confirmation (use with caution!)
    ./$(basename "$0") --force
    
    # Destroy + cleanup orphaned resources
    ./$(basename "$0") --cleanup

EOF
}

load_aws_credentials() {
    log_info "Loading AWS credentials..."
    
    if [[ -f "$TFVARS_FILE" ]]; then
        export AWS_ACCESS_KEY_ID=$(grep -E "^aws_access_key\s*=" "$TFVARS_FILE" | cut -d'"' -f2 || echo "")
        export AWS_SECRET_ACCESS_KEY=$(grep -E "^aws_secret_key\s*=" "$TFVARS_FILE" | cut -d'"' -f2 || echo "")
        export AWS_DEFAULT_REGION=$(grep -E "^aws_region\s*=" "$TFVARS_FILE" | cut -d'"' -f2 || echo "us-east-1")
    fi
    
    if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        log_error "AWS credentials not found!"
        exit 1
    fi
    
    log_success "AWS credentials loaded"
}

get_resource_count() {
    cd "$TERRAFORM_DIR"
    if terraform state list &>/dev/null 2>&1; then
        terraform state list 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

show_resources() {
    cd "$TERRAFORM_DIR"
    
    log_info "Current infrastructure resources:"
    echo ""
    
    if terraform state list &>/dev/null 2>&1; then
        terraform state list | while read -r resource; do
            echo "  • $resource"
        done
    else
        echo "  (No resources found or state not initialized)"
    fi
    echo ""
}

cleanup_orphaned_resources() {
    log_info "Cleaning up orphaned AWS resources..."
    
    # Get project name from tfvars for filtering
    local project_name=$(grep -E "^project_name\s*=" "$TFVARS_FILE" | cut -d'"' -f2 || echo "devops-testing-app")
    
    log_info "Looking for resources tagged with project: $project_name"
    
    # Find and terminate EC2 instances
    log_info "Checking for orphaned EC2 instances..."
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=$project_name" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$instances" && "$instances" != "None" ]]; then
        log_warning "Found orphaned instances: $instances"
        if [[ "$DRY_RUN" != true ]]; then
            aws ec2 terminate-instances --instance-ids $instances
            log_info "Waiting for instances to terminate..."
            aws ec2 wait instance-terminated --instance-ids $instances 2>/dev/null || true
            log_success "Instances terminated"
        fi
    else
        log_info "No orphaned instances found"
    fi
    
    # Find and release Elastic IPs
    log_info "Checking for orphaned Elastic IPs..."
    local eips=$(aws ec2 describe-addresses \
        --filters "Name=tag:Project,Values=$project_name" \
        --query 'Addresses[].AllocationId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$eips" && "$eips" != "None" ]]; then
        log_warning "Found orphaned EIPs: $eips"
        if [[ "$DRY_RUN" != true ]]; then
            for eip in $eips; do
                aws ec2 release-address --allocation-id "$eip" 2>/dev/null || true
            done
            log_success "EIPs released"
        fi
    else
        log_info "No orphaned EIPs found"
    fi
    
    # Find and delete NAT Gateways
    log_info "Checking for orphaned NAT Gateways..."
    local nat_gws=$(aws ec2 describe-nat-gateways \
        --filter "Name=tag:Project,Values=$project_name" "Name=state,Values=available,pending" \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$nat_gws" && "$nat_gws" != "None" ]]; then
        log_warning "Found orphaned NAT Gateways: $nat_gws"
        if [[ "$DRY_RUN" != true ]]; then
            for nat in $nat_gws; do
                aws ec2 delete-nat-gateway --nat-gateway-id "$nat" 2>/dev/null || true
            done
            sleep 30  # Wait for NAT gateway deletion
            log_success "NAT Gateways deleted"
        fi
    else
        log_info "No orphaned NAT Gateways found"
    fi
    
    # Find and delete Security Groups (non-default)
    log_info "Checking for orphaned Security Groups..."
    local sgs=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=$project_name" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$sgs" && "$sgs" != "None" ]]; then
        log_warning "Found orphaned Security Groups: $sgs"
        if [[ "$DRY_RUN" != true ]]; then
            for sg in $sgs; do
                aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
            done
            log_success "Security Groups deleted"
        fi
    else
        log_info "No orphaned Security Groups found"
    fi
    
    # Find and delete Subnets
    log_info "Checking for orphaned Subnets..."
    local subnets=$(aws ec2 describe-subnets \
        --filters "Name=tag:Project,Values=$project_name" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$subnets" && "$subnets" != "None" ]]; then
        log_warning "Found orphaned Subnets: $subnets"
        if [[ "$DRY_RUN" != true ]]; then
            for subnet in $subnets; do
                aws ec2 delete-subnet --subnet-id "$subnet" 2>/dev/null || true
            done
            log_success "Subnets deleted"
        fi
    else
        log_info "No orphaned Subnets found"
    fi
    
    # Find and delete Internet Gateways
    log_info "Checking for orphaned Internet Gateways..."
    local igws=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Project,Values=$project_name" \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$igws" && "$igws" != "None" ]]; then
        log_warning "Found orphaned Internet Gateways: $igws"
        if [[ "$DRY_RUN" != true ]]; then
            for igw in $igws; do
                # First detach from VPC
                local vpc=$(aws ec2 describe-internet-gateways \
                    --internet-gateway-ids "$igw" \
                    --query 'InternetGateways[].Attachments[].VpcId' \
                    --output text 2>/dev/null || echo "")
                if [[ -n "$vpc" && "$vpc" != "None" ]]; then
                    aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" 2>/dev/null || true
                fi
                aws ec2 delete-internet-gateway --internet-gateway-id "$igw" 2>/dev/null || true
            done
            log_success "Internet Gateways deleted"
        fi
    else
        log_info "No orphaned Internet Gateways found"
    fi
    
    # Find and delete VPCs
    log_info "Checking for orphaned VPCs..."
    local vpcs=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=$project_name" \
        --query 'Vpcs[].VpcId' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$vpcs" && "$vpcs" != "None" ]]; then
        log_warning "Found orphaned VPCs: $vpcs"
        if [[ "$DRY_RUN" != true ]]; then
            for vpc in $vpcs; do
                # Delete route tables (except main)
                local rts=$(aws ec2 describe-route-tables \
                    --filters "Name=vpc-id,Values=$vpc" \
                    --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
                    --output text 2>/dev/null || echo "")
                for rt in $rts; do
                    aws ec2 delete-route-table --route-table-id "$rt" 2>/dev/null || true
                done
                
                aws ec2 delete-vpc --vpc-id "$vpc" 2>/dev/null || true
            done
            log_success "VPCs deleted"
        fi
    else
        log_info "No orphaned VPCs found"
    fi
    
    log_success "Orphaned resource cleanup complete"
}

destroy() {
    cd "$TERRAFORM_DIR"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  INFRASTRUCTURE DESTRUCTION ⚠️                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Initialize terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init -upgrade
    fi
    
    # Show current resources
    local resource_count=$(get_resource_count)
    log_warning "This will destroy $resource_count resources!"
    echo ""
    
    show_resources
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Showing destruction plan..."
        terraform plan -destroy
        log_info "[DRY-RUN] No changes made."
        
        if [[ "$CLEANUP" == true ]]; then
            cleanup_orphaned_resources
        fi
        
        return 0
    fi
    
    if [[ "$FORCE" != true ]]; then
        echo ""
        log_warning "This action CANNOT be undone!"
        log_warning "All EC2 instances, EIPs, VPCs, and other resources will be permanently deleted."
        echo ""
        read -p "Type 'destroy' to confirm: " confirm
        
        if [[ "$confirm" != "destroy" ]]; then
            log_info "Destruction cancelled."
            exit 0
        fi
    else
        log_warning "Force mode enabled - skipping confirmation"
    fi
    
    echo ""
    log_info "Destroying infrastructure (this may take 3-5 minutes)..."
    
    # Run terraform destroy
    terraform destroy -auto-approve
    local tf_result=$?
    
    if [[ $tf_result -ne 0 ]]; then
        log_error "Terraform destroy had errors. Attempting cleanup of orphaned resources..."
        CLEANUP=true
    fi
    
    # Cleanup orphaned resources if requested or if destroy had errors
    if [[ "$CLEANUP" == true ]]; then
        cleanup_orphaned_resources
    fi
    
    # Clean up local state files
    log_info "Cleaning up local state files..."
    rm -f terraform.tfstate terraform.tfstate.backup tfplan .terraform.lock.hcl 2>/dev/null || true
    
    echo ""
    log_success "Infrastructure destroyed successfully!"
    
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                         Infrastructure Destroyed                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

  All AWS resources have been terminated.
  Local Terraform state has been cleaned up.
  
  To verify cleanup, run:
    aws ec2 describe-instances --filters "Name=tag:Project,Values=devops-testing-app"
    aws ec2 describe-vpcs --filters "Name=tag:Project,Values=devops-testing-app"
  
  To recreate the infrastructure, run:
    ./scripts/bootstrap-infrastructure.sh

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
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

# Check terraform is available
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    exit 1
fi

# Check terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    log_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Load AWS credentials
load_aws_credentials

# Run destruction
destroy
