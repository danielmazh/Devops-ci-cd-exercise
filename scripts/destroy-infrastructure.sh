#!/usr/bin/env bash
# =============================================================================
# Destroy Infrastructure Script
# =============================================================================
# Safely tears down all AWS infrastructure created by Terraform
#
# Usage:
#   ./destroy-infrastructure.sh [OPTIONS]
#
# Options:
#   --force    Skip confirmation prompt
#   --dry-run  Show what would be destroyed without executing
#   --help     Show this help message
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
FORCE=false
DRY_RUN=false

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
    --help      Show this help message

EXAMPLES:
    # Interactive destruction (with confirmation)
    ./$(basename "$0")
    
    # Preview what would be destroyed
    ./$(basename "$0") --dry-run
    
    # Force destroy without confirmation (use with caution!)
    ./$(basename "$0") --force

EOF
}

get_resource_count() {
    cd "$TERRAFORM_DIR"
    terraform state list 2>/dev/null | wc -l | tr -d ' '
}

show_resources() {
    cd "$TERRAFORM_DIR"
    
    log_info "Current infrastructure resources:"
    echo ""
    
    if terraform state list &>/dev/null; then
        terraform state list | while read -r resource; do
            echo "  • $resource"
        done
    else
        echo "  (No resources found or state not initialized)"
    fi
    echo ""
}

destroy() {
    cd "$TERRAFORM_DIR"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  INFRASTRUCTURE DESTRUCTION ⚠️                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Show current resources
    local resource_count=$(get_resource_count)
    log_warning "This will destroy $resource_count resources!"
    echo ""
    
    show_resources
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Showing destruction plan..."
        terraform plan -destroy
        log_info "[DRY-RUN] No changes made."
        return 0
    fi
    
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
    log_info "Destroying infrastructure..."
    
    # Run terraform destroy
    terraform destroy -auto-approve
    
    echo ""
    log_success "Infrastructure destroyed successfully!"
    
    cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                         Infrastructure Destroyed                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

  All AWS resources have been terminated.
  
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

# Run destruction
destroy
