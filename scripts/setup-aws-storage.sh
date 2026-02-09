#!/usr/bin/env bash
# =============================================================================
# Setup AWS Storage for Credentials & Terraform State
# =============================================================================
# Creates:
#   - S3 bucket for Terraform state (with versioning & encryption)
#   - Parameter Store entries for secrets (FREE tier)
#   - DynamoDB table for state locking (optional)
#
# Usage:
#   ./setup-aws-storage.sh
#
# Cost:
#   - Parameter Store (Standard): FREE
#   - S3: ~$0.001/month for state files
#   - DynamoDB: FREE tier (25GB)
# =============================================================================

set -euo pipefail

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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load AWS credentials from tfvars
load_credentials() {
    log_info "Loading credentials from terraform.tfvars..."
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        log_error "terraform.tfvars not found at $TFVARS_FILE"
        exit 1
    fi
    
    export AWS_ACCESS_KEY_ID=$(grep -E "^aws_access_key\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    export AWS_SECRET_ACCESS_KEY=$(grep -E "^aws_secret_key\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    export AWS_DEFAULT_REGION=$(grep -E "^aws_region\s*=" "$TFVARS_FILE" | cut -d'"' -f2 || echo "us-east-1")
    
    # Get account ID for unique bucket name
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_NAME="devops-tfstate-${ACCOUNT_ID}"
    DYNAMODB_TABLE="devops-tfstate-lock"
    
    log_success "AWS Account: $ACCOUNT_ID"
    log_success "Region: $AWS_DEFAULT_REGION"
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    log_info "Creating S3 bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        log_warning "Bucket $BUCKET_NAME already exists"
        return 0
    fi
    
    # Create bucket (us-east-1 doesn't need LocationConstraint)
    if [[ "$AWS_DEFAULT_REGION" == "us-east-1" ]]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'
    
    # Add tags
    aws s3api put-bucket-tagging \
        --bucket "$BUCKET_NAME" \
        --tagging 'TagSet=[{Key=Project,Value=devops-testing-app},{Key=Purpose,Value=terraform-state}]'
    
    log_success "S3 bucket created with versioning and encryption"
}

# Create DynamoDB table for state locking
create_dynamodb_table() {
    log_info "Creating DynamoDB table: $DYNAMODB_TABLE"
    
    # Check if table exists
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" 2>/dev/null; then
        log_warning "DynamoDB table $DYNAMODB_TABLE already exists"
        return 0
    fi
    
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --tags Key=Project,Value=devops-testing-app Key=Purpose,Value=terraform-lock
    
    # Wait for table to be active
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
    
    log_success "DynamoDB table created"
}

# Store secrets in Parameter Store
store_secrets() {
    log_info "Storing secrets in AWS Parameter Store (FREE tier)..."
    
    # Read secrets from tfvars
    local docker_hub_token=$(grep -E "^docker_hub_token\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local docker_hub_username=$(grep -E "^docker_hub_username\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local github_token=$(grep -E "^github_token\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local github_username=$(grep -E "^github_username\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local jira_api_token=$(grep -E "^jira_api_token\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local jira_url=$(grep -E "^jira_url\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local jira_email=$(grep -E "^jira_email\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local jenkins_password=$(grep -E "^jenkins_admin_password\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local ssh_key_path=$(grep -E "^ssh_private_key_path\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    
    # SMTP/Email settings
    local smtp_host=$(grep -E "^smtp_host\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local smtp_port=$(grep -E "^smtp_port\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local smtp_username=$(grep -E "^smtp_username\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    local smtp_password=$(grep -E "^smtp_password\s*=" "$TFVARS_FILE" | cut -d'"' -f2)
    
    # Store each secret (overwrite if exists)
    store_parameter "/devops/docker_hub_username" "$docker_hub_username" "Docker Hub username"
    store_parameter "/devops/docker_hub_token" "$docker_hub_token" "Docker Hub token" "SecureString"
    store_parameter "/devops/github_username" "$github_username" "GitHub username"
    store_parameter "/devops/github_token" "$github_token" "GitHub token" "SecureString"
    store_parameter "/devops/jira_url" "$jira_url" "JIRA URL"
    store_parameter "/devops/jira_email" "$jira_email" "JIRA email"
    store_parameter "/devops/jira_api_token" "$jira_api_token" "JIRA API token" "SecureString"
    store_parameter "/devops/jenkins_password" "$jenkins_password" "Jenkins admin password" "SecureString"
    store_parameter "/devops/ssh_key_path" "$ssh_key_path" "SSH key path"
    
    # SMTP/Email parameters
    store_parameter "/devops/smtp_host" "$smtp_host" "SMTP server hostname"
    store_parameter "/devops/smtp_port" "$smtp_port" "SMTP server port"
    store_parameter "/devops/smtp_username" "$smtp_username" "SMTP username (email)"
    store_parameter "/devops/smtp_password" "$smtp_password" "SMTP password (app password)" "SecureString"
    
    log_success "All secrets stored in Parameter Store"
}

store_parameter() {
    local name=$1
    local value=$2
    local description=$3
    local type=${4:-"String"}
    
    if [[ -z "$value" ]]; then
        log_warning "Skipping $name (empty value)"
        return
    fi
    
    aws ssm put-parameter \
        --name "$name" \
        --value "$value" \
        --type "$type" \
        --description "$description" \
        --overwrite \
        --tags "Key=Project,Value=devops-testing-app" 2>/dev/null || true
    
    log_info "  ✓ Stored: $name"
}

# Create Terraform backend configuration
create_backend_config() {
    log_info "Creating Terraform backend configuration..."
    
    cat > "$TERRAFORM_DIR/backend.tf" << EOF
# =============================================================================
# Terraform Backend Configuration - S3 + DynamoDB
# =============================================================================
# Auto-generated by setup-aws-storage.sh
# This stores Terraform state in S3 with locking via DynamoDB
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "devops-testing-app/terraform.tfstate"
    region         = "$AWS_DEFAULT_REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }
}
EOF

    log_success "Created backend.tf"
    log_warning "Run 'terraform init -migrate-state' to migrate existing state to S3"
}

# Print summary
print_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    AWS Storage Setup Complete                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  📦 S3 Bucket (Terraform State):"
    echo "     Name: $BUCKET_NAME"
    echo "     Cost: ~\$0.001/month"
    echo ""
    echo "  🔒 Parameter Store (Secrets):"
    echo "     /devops/docker_hub_username"
    echo "     /devops/docker_hub_token (encrypted)"
    echo "     /devops/github_username"
    echo "     /devops/github_token (encrypted)"
    echo "     /devops/jira_url"
    echo "     /devops/jira_email"
    echo "     /devops/jira_api_token (encrypted)"
    echo "     /devops/jenkins_password (encrypted)"
    echo "     /devops/ssh_key_path"
    echo "     /devops/smtp_host"
    echo "     /devops/smtp_port"
    echo "     /devops/smtp_username"
    echo "     /devops/smtp_password (encrypted)"
    echo "     Cost: FREE (Standard tier)"
    echo ""
    echo "  🔐 DynamoDB Table (State Locking):"
    echo "     Name: $DYNAMODB_TABLE"
    echo "     Cost: FREE (on-demand, minimal usage)"
    echo ""
    echo "  📋 Next Steps:"
    echo "     1. Run: cd infrastructure/terraform && terraform init -migrate-state"
    echo "     2. Confirm state migration when prompted"
    echo "     3. Run bootstrap-infrastructure.sh as usual"
    echo ""
    echo "  ⚠️  To delete these resources later:"
    echo "     ./scripts/destroy-infrastructure.sh --cleanup --delete-storage"
    echo ""
}

# Main
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    AWS Storage Setup for DevOps Project                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    load_credentials
    create_s3_bucket
    create_dynamodb_table
    store_secrets
    create_backend_config
    print_summary
}

main "$@"
