#!/usr/bin/env bash
# =============================================================================
# Destroy Infrastructure Script - COMPLETE CLEANUP
# =============================================================================
# Safely tears down ALL AWS infrastructure created by Terraform
# Optionally deletes persistent storage (S3, Parameter Store, DynamoDB)
#
# Usage:
#   ./destroy-infrastructure.sh [OPTIONS]
#
# Options:
#   --force           Skip confirmation prompt
#   --dry-run         Show what would be destroyed without executing
#   --cleanup         Clean up orphaned resources not in state file
#   --delete-storage  Also delete S3 bucket, Parameter Store secrets, DynamoDB
#   --help            Show this help message
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
DELETE_STORAGE=false

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
    --force           Skip confirmation prompt (DANGEROUS!)
    --dry-run         Show what would be destroyed without executing
    --cleanup         Also clean up orphaned AWS resources not in Terraform state
    --delete-storage  Delete persistent storage (S3 bucket, Parameter Store, DynamoDB)
    --help            Show this help message

EXAMPLES:
    # Interactive destruction (with confirmation)
    ./$(basename "$0")
    
    # Preview what would be destroyed
    ./$(basename "$0") --dry-run
    
    # Force destroy without confirmation (use with caution!)
    ./$(basename "$0") --force
    
    # Destroy + cleanup orphaned resources
    ./$(basename "$0") --cleanup
    
    # COMPLETE CLEANUP (everything including storage) - for end of course
    ./$(basename "$0") --cleanup --delete-storage

PERSISTENT STORAGE (only deleted with --delete-storage):
    - S3 Bucket: Terraform state files (~\$0.001/month)
    - Parameter Store: Encrypted credentials (FREE)
    - DynamoDB Table: State locking (FREE)

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
    
    # Get account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
    BUCKET_NAME="devops-tfstate-${ACCOUNT_ID}"
    DYNAMODB_TABLE="devops-tfstate-lock"
    
    log_success "AWS credentials loaded (Account: $ACCOUNT_ID)"
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

delete_persistent_storage() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║              ⚠️  PERSISTENT STORAGE DELETION ⚠️                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  This will DELETE the following resources:"
    echo ""
    echo "  📦 S3 Bucket: $BUCKET_NAME"
    echo "     Contains: Terraform state files"
    echo "     Impact: State history will be PERMANENTLY LOST"
    echo "     Cost saved: ~\$0.001/month"
    echo ""
    echo "  🔒 Parameter Store Secrets:"
    echo "     /devops/docker_hub_username"
    echo "     /devops/docker_hub_token"
    echo "     /devops/github_username"
    echo "     /devops/github_token"
    echo "     /devops/jira_url"
    echo "     /devops/jira_email"
    echo "     /devops/jira_api_token"
    echo "     /devops/jenkins_password"
    echo "     /devops/ssh_key_path"
    echo "     Impact: You'll need to re-enter credentials"
    echo "     Cost saved: \$0 (already FREE)"
    echo ""
    echo "  🔐 DynamoDB Table: $DYNAMODB_TABLE"
    echo "     Contains: Terraform state locks"
    echo "     Impact: Lock history lost (no practical impact)"
    echo "     Cost saved: \$0 (FREE tier)"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would delete all persistent storage"
        return 0
    fi
    
    if [[ "$FORCE" != true ]]; then
        echo -e "${YELLOW}  ⚠️  This action CANNOT be undone!${NC}"
        echo ""
        read -p "  Type 'DELETE ALL' to confirm: " confirm
        
        if [[ "$confirm" != "DELETE ALL" ]]; then
            log_info "Storage deletion cancelled"
            return 0
        fi
    fi
    
    echo ""
    log_info "Deleting persistent storage..."
    
    # Delete S3 bucket (must empty first)
    log_info "Deleting S3 bucket: $BUCKET_NAME"
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        # Empty the bucket (including versions)
        aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
            jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' 2>/dev/null | \
            while read -r args; do
                eval "aws s3api delete-object --bucket $BUCKET_NAME $args" 2>/dev/null || true
            done
        
        # Delete delete markers
        aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
            jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' 2>/dev/null | \
            while read -r args; do
                eval "aws s3api delete-object --bucket $BUCKET_NAME $args" 2>/dev/null || true
            done
        
        # Delete bucket
        aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null || true
        log_success "S3 bucket deleted"
    else
        log_info "S3 bucket not found (already deleted or never created)"
    fi
    
    # Delete Parameter Store secrets
    log_info "Deleting Parameter Store secrets..."
    local params=(
        "/devops/docker_hub_username"
        "/devops/docker_hub_token"
        "/devops/github_username"
        "/devops/github_token"
        "/devops/jira_url"
        "/devops/jira_email"
        "/devops/jira_api_token"
        "/devops/jenkins_password"
        "/devops/ssh_key_path"
    )
    
    for param in "${params[@]}"; do
        if aws ssm get-parameter --name "$param" 2>/dev/null; then
            aws ssm delete-parameter --name "$param" 2>/dev/null || true
            log_info "  ✓ Deleted: $param"
        fi
    done
    log_success "Parameter Store secrets deleted"
    
    # Delete DynamoDB table
    log_info "Deleting DynamoDB table: $DYNAMODB_TABLE"
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" 2>/dev/null; then
        aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" 2>/dev/null || true
        aws dynamodb wait table-not-exists --table-name "$DYNAMODB_TABLE" 2>/dev/null || true
        log_success "DynamoDB table deleted"
    else
        log_info "DynamoDB table not found (already deleted or never created)"
    fi
    
    # Remove backend.tf to switch back to local state
    if [[ -f "$TERRAFORM_DIR/backend.tf" ]]; then
        rm -f "$TERRAFORM_DIR/backend.tf"
        log_info "Removed backend.tf (switched back to local state)"
    fi
    
    log_success "All persistent storage deleted!"
    echo ""
    echo "  💰 Total ongoing AWS costs: \$0.00/month"
    echo ""
}

ask_about_storage() {
    if [[ "$DELETE_STORAGE" == true ]]; then
        return 0  # Already set via command line
    fi
    
    # Check if storage exists
    local storage_exists=false
    
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        storage_exists=true
    fi
    
    if aws ssm get-parameter --name "/devops/docker_hub_token" 2>/dev/null >/dev/null; then
        storage_exists=true
    fi
    
    if [[ "$storage_exists" == false ]]; then
        return 1  # No storage to delete
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Persistent Storage Detected                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  The following persistent storage exists in AWS:"
    echo ""
    echo "  📦 S3 Bucket: $BUCKET_NAME (Terraform state)"
    echo "  🔒 Parameter Store: /devops/* (Credentials)"
    echo "  🔐 DynamoDB: $DYNAMODB_TABLE (State locking)"
    echo ""
    echo "  Options:"
    echo "    [K]eep  - Keep storage for future deployments (recommended if continuing course)"
    echo "    [D]elete - Delete ALL storage (recommended at END of course to avoid any costs)"
    echo ""
    
    if [[ "$FORCE" == true ]]; then
        log_info "Force mode: keeping storage (use --delete-storage to delete)"
        return 1
    fi
    
    read -p "  Do you want to delete persistent storage? [K/D]: " choice
    
    case "${choice,,}" in
        d|delete)
            DELETE_STORAGE=true
            return 0
            ;;
        *)
            log_info "Keeping persistent storage"
            return 1
            ;;
    esac
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
        terraform init -upgrade 2>/dev/null || terraform init
    fi
    
    # Show current resources
    local resource_count=$(get_resource_count)
    
    if [[ "$resource_count" == "0" ]]; then
        log_info "No infrastructure resources to destroy"
    else
        log_warning "This will destroy $resource_count resources!"
        echo ""
        show_resources
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Showing destruction plan..."
        if [[ "$resource_count" != "0" ]]; then
            terraform plan -destroy
        fi
        
        if [[ "$CLEANUP" == true ]]; then
            cleanup_orphaned_resources
        fi
        
        if [[ "$DELETE_STORAGE" == true ]]; then
            delete_persistent_storage
        fi
        
        log_info "[DRY-RUN] No changes made."
        return 0
    fi
    
    if [[ "$resource_count" != "0" ]]; then
        if [[ "$FORCE" != true ]]; then
            echo ""
            log_warning "This action CANNOT be undone!"
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
    fi
    
    # Cleanup orphaned resources if requested or if destroy had errors
    if [[ "$CLEANUP" == true ]]; then
        cleanup_orphaned_resources
    fi
    
    # Ask about persistent storage
    if ask_about_storage; then
        delete_persistent_storage
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

  All AWS EC2/VPC resources have been terminated.
EOF

    if [[ "$DELETE_STORAGE" == true ]]; then
        cat << EOF
  All persistent storage (S3, Parameter Store, DynamoDB) has been deleted.
  
  💰 Total ongoing AWS costs: \$0.00/month
EOF
    else
        cat << EOF
  
  ℹ️  Persistent storage was KEPT:
      - S3 Bucket: $BUCKET_NAME
      - Parameter Store: /devops/*
      - DynamoDB: $DYNAMODB_TABLE
      
  💰 Ongoing cost: ~\$0.001/month (essentially free)
  
  To delete storage later, run:
      ./scripts/destroy-infrastructure.sh --delete-storage
EOF
    fi
    
    cat << EOF
  
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
        --delete-storage)
            DELETE_STORAGE=true
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
