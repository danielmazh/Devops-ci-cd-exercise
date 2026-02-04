#!/usr/bin/env bash
# =============================================================================
# Test Runner Script
# =============================================================================
# Runs the test suite with coverage and generates reports
#
# Usage:
#   ./run-tests.sh [OPTIONS]
#
# Options:
#   --unit         Run only unit tests
#   --integration  Run only integration tests
#   --e2e          Run only e2e tests
#   --performance  Run performance tests
#   --all          Run all tests (default)
#   --coverage     Generate coverage report (default: on)
#   --no-coverage  Skip coverage report
#   --help         Show this help message
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Defaults
RUN_UNIT=false
RUN_INTEGRATION=false
RUN_E2E=false
RUN_PERFORMANCE=false
RUN_ALL=true
COVERAGE=true

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
log_step() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                              Test Runner Script                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --unit          Run only unit tests
    --integration   Run only integration tests
    --e2e           Run only E2E tests
    --performance   Run performance tests (requires running app)
    --all           Run all tests (default)
    --coverage      Generate coverage report (default: on)
    --no-coverage   Skip coverage report
    --help          Show this help message

EXAMPLES:
    # Run all tests with coverage
    ./$(basename "$0")
    
    # Run only unit tests
    ./$(basename "$0") --unit
    
    # Run unit and integration tests
    ./$(basename "$0") --unit --integration
    
    # Run performance tests
    ./$(basename "$0") --performance

OUTPUT:
    Reports are saved to:
    - reports/unit-tests.xml
    - reports/integration-tests.xml
    - reports/e2e-tests.xml
    - reports/performance-report.html
    - htmlcov/index.html (coverage)

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            RUN_UNIT=true
            RUN_ALL=false
            shift
            ;;
        --integration)
            RUN_INTEGRATION=true
            RUN_ALL=false
            shift
            ;;
        --e2e)
            RUN_E2E=true
            RUN_ALL=false
            shift
            ;;
        --performance)
            RUN_PERFORMANCE=true
            RUN_ALL=false
            shift
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --no-coverage)
            COVERAGE=false
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

cd "$PROJECT_ROOT"

# Check virtual environment
if [[ ! -d "venv" ]]; then
    log_info "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
log_info "Installing dependencies..."
pip install -q -r requirements.txt
pip install -q pytest pytest-cov pytest-html flake8 pylint bandit locust

# Create reports directory
mkdir -p reports htmlcov

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                              Test Runner                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Track results
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

run_test_suite() {
    local name="$1"
    local path="$2"
    local report_name="$3"
    
    log_step "Running $name Tests"
    
    local cov_args=""
    if [[ "$COVERAGE" == true ]]; then
        cov_args="--cov=app --cov-append --cov-report="
    fi
    
    set +e
    pytest "$path" -v \
        $cov_args \
        --junit-xml="reports/${report_name}.xml" \
        --html="reports/${report_name}.html" \
        --self-contained-html
    local exit_code=$?
    set -e
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$name tests PASSED"
        ((TESTS_PASSED++))
    else
        log_error "$name tests FAILED"
        ((TESTS_FAILED++))
    fi
    ((TOTAL_TESTS++))
    
    return $exit_code
}

# Clear coverage data
if [[ "$COVERAGE" == true ]]; then
    rm -f .coverage
fi

# Run tests based on options
EXIT_CODE=0

if [[ "$RUN_ALL" == true ]] || [[ "$RUN_UNIT" == true ]]; then
    run_test_suite "Unit" "tests/unit/ tests/test_calc.py" "unit-tests" || EXIT_CODE=1
fi

if [[ "$RUN_ALL" == true ]] || [[ "$RUN_INTEGRATION" == true ]]; then
    run_test_suite "Integration" "tests/integration/" "integration-tests" || EXIT_CODE=1
fi

if [[ "$RUN_ALL" == true ]] || [[ "$RUN_E2E" == true ]]; then
    run_test_suite "E2E" "tests/e2e/" "e2e-tests" || true  # E2E may fail without browser
fi

if [[ "$RUN_PERFORMANCE" == true ]]; then
    log_step "Running Performance Tests"
    
    log_info "Starting application for performance tests..."
    python main.py &
    APP_PID=$!
    sleep 5
    
    set +e
    locust -f tests/performance/locustfile.py \
        --headless \
        --users 10 \
        --spawn-rate 2 \
        --run-time 30s \
        --host http://localhost:5000 \
        --html reports/performance-report.html
    PERF_EXIT=$?
    set -e
    
    kill $APP_PID 2>/dev/null || true
    
    if [[ $PERF_EXIT -eq 0 ]]; then
        log_success "Performance tests completed"
    else
        log_warning "Performance tests had issues"
    fi
fi

# Generate coverage report
if [[ "$COVERAGE" == true ]] && [[ -f ".coverage" ]]; then
    log_step "Generating Coverage Report"
    
    coverage html -d htmlcov
    coverage xml -o reports/coverage.xml
    coverage report
    
    log_success "Coverage report generated: htmlcov/index.html"
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                              Test Summary                                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Passed: $TESTS_PASSED"
echo "  ❌ Failed: $TESTS_FAILED"
echo "  📊 Total:  $TOTAL_TESTS"
echo ""
echo "  📁 Reports:"
echo "     - reports/unit-tests.html"
echo "     - reports/integration-tests.html"
echo "     - reports/e2e-tests.html"
if [[ "$COVERAGE" == true ]]; then
echo "     - htmlcov/index.html (coverage)"
fi
if [[ "$RUN_PERFORMANCE" == true ]]; then
echo "     - reports/performance-report.html"
fi
echo ""

# Open coverage report (macOS)
if [[ "$COVERAGE" == true ]] && [[ -f "htmlcov/index.html" ]]; then
    if command -v open &> /dev/null; then
        read -p "Open coverage report in browser? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open htmlcov/index.html
        fi
    fi
fi

exit $EXIT_CODE
