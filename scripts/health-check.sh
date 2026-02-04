#!/usr/bin/env bash
# =============================================================================
# Health Check Script
# =============================================================================
# Verifies the health of deployed infrastructure and application
#
# Usage:
#   ./health-check.sh [OPTIONS]
#
# Options:
#   --jenkins-ip IP  Jenkins server IP (auto-detected from Terraform)
#   --app-ip IP      Application server IP (auto-detected from Terraform)
#   --timeout SEC    Timeout in seconds (default: 60)
#   --verbose        Show detailed output
#   --help           Show this help message
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"

# Defaults
JENKINS_IP=""
APP_IP=""
TIMEOUT=60
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                            Health Check Script                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --jenkins-ip IP   Jenkins server IP (auto-detected from Terraform if not set)
    --app-ip IP       Application server IP (auto-detected from Terraform if not set)
    --timeout SEC     Timeout for each check in seconds (default: 60)
    --verbose         Show detailed output
    --help            Show this help message

EXAMPLES:
    # Auto-detect IPs from Terraform and check
    ./$(basename "$0")
    
    # Check specific IPs
    ./$(basename "$0") --jenkins-ip 1.2.3.4 --app-ip 5.6.7.8
    
    # Verbose output
    ./$(basename "$0") --verbose

CHECKS PERFORMED:
    1. Jenkins UI accessibility (port 8080)
    2. Jenkins API health
    3. Application health endpoint
    4. Application API endpoints
    5. SSH connectivity

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --jenkins-ip)
            JENKINS_IP="$2"
            shift 2
            ;;
        --app-ip)
            APP_IP="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
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

# Get IPs from Terraform if not provided
get_terraform_outputs() {
    if [[ -z "$JENKINS_IP" ]] || [[ -z "$APP_IP" ]]; then
        log_info "Getting IPs from Terraform..."
        
        cd "$TERRAFORM_DIR"
        
        if [[ -z "$JENKINS_IP" ]]; then
            JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
        fi
        
        if [[ -z "$APP_IP" ]]; then
            APP_IP=$(terraform output -raw app_public_ip 2>/dev/null || echo "")
        fi
        
        cd "$PROJECT_ROOT"
    fi
    
    if [[ -z "$JENKINS_IP" ]]; then
        log_error "Could not determine Jenkins IP. Use --jenkins-ip or run terraform apply first."
        exit 1
    fi
    
    if [[ -z "$APP_IP" ]]; then
        log_error "Could not determine App IP. Use --app-ip or run terraform apply first."
        exit 1
    fi
}

check_url() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    if [[ "$VERBOSE" == true ]]; then
        log_info "Checking: $url"
    fi
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
        
        if [[ "$response" == "$expected_code" ]] || [[ "$response" == "200" ]] || [[ "$response" == "302" ]]; then
            log_success "$name (HTTP $response)"
            return 0
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            log_info "  Got HTTP $response, retrying..."
        fi
        sleep 5
    done
    
    log_error "$name (timeout after ${TIMEOUT}s)"
    return 1
}

check_port() {
    local name="$1"
    local host="$2"
    local port="$3"
    
    if nc -z -w5 "$host" "$port" 2>/dev/null; then
        log_success "$name ($host:$port)"
        return 0
    else
        log_error "$name ($host:$port not reachable)"
        return 1
    fi
}

check_health_json() {
    local name="$1"
    local url="$2"
    
    local response=$(curl -s --connect-timeout 5 "$url" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q "healthy"; then
        log_success "$name"
        if [[ "$VERBOSE" == true ]]; then
            echo "      Response: $response"
        fi
        return 0
    else
        log_error "$name"
        if [[ "$VERBOSE" == true ]]; then
            echo "      Response: $response"
        fi
        return 1
    fi
}

# Main
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        Infrastructure Health Check                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

get_terraform_outputs

log_info "Jenkins IP: $JENKINS_IP"
log_info "App IP:     $APP_IP"
log_info "Timeout:    ${TIMEOUT}s"
echo ""

# Track results
PASSED=0
FAILED=0

echo "─── Network Connectivity ───"
check_port "Jenkins SSH" "$JENKINS_IP" 22 && ((PASSED++)) || ((FAILED++))
check_port "Jenkins HTTP" "$JENKINS_IP" 8080 && ((PASSED++)) || ((FAILED++))
check_port "App SSH" "$APP_IP" 22 && ((PASSED++)) || ((FAILED++))
check_port "App HTTP" "$APP_IP" 80 && ((PASSED++)) || ((FAILED++))
echo ""

echo "─── Jenkins Health ───"
check_url "Jenkins Login Page" "http://$JENKINS_IP:8080/login" && ((PASSED++)) || ((FAILED++))
echo ""

echo "─── Application Health ───"
check_health_json "App Health Endpoint" "http://$APP_IP/health" && ((PASSED++)) || ((FAILED++))
check_url "App Users API" "http://$APP_IP/api/users/" && ((PASSED++)) || ((FAILED++))
check_url "App Products API" "http://$APP_IP/api/products/" && ((PASSED++)) || ((FAILED++))
echo ""

# Summary
TOTAL=$((PASSED + FAILED))
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                              Health Summary                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Passed: $PASSED / $TOTAL"
echo "  ❌ Failed: $FAILED / $TOTAL"
echo ""

if [[ $FAILED -eq 0 ]]; then
    log_success "All health checks passed!"
    echo ""
    echo "  🔗 Jenkins: http://$JENKINS_IP:8080"
    echo "  🔗 App:     http://$APP_IP"
    echo ""
    exit 0
else
    log_error "Some health checks failed!"
    echo ""
    echo "  Troubleshooting:"
    echo "    - Check security groups allow inbound traffic"
    echo "    - Verify instances are running: aws ec2 describe-instances"
    echo "    - Check cloud-init logs: ssh ec2-user@IP 'sudo cat /var/log/cloud-init-output.log'"
    echo ""
    exit 1
fi
