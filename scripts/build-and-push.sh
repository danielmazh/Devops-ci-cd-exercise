#!/usr/bin/env bash
# =============================================================================
# Docker Build and Push Script
# =============================================================================
# Builds the Docker image and pushes to Docker Hub
#
# Usage:
#   ./build-and-push.sh [OPTIONS]
#
# Options:
#   --tag TAG      Image tag (default: latest)
#   --no-push      Build only, don't push
#   --no-cache     Build without cache
#   --help         Show this help message
#
# Environment Variables:
#   DOCKER_HUB_USERNAME  Docker Hub username (required for push)
#   DOCKER_HUB_TOKEN     Docker Hub access token (required for push)
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Defaults
IMAGE_NAME="${DOCKER_HUB_USERNAME:-danielmazh}/devops-testing-app"
TAG="latest"
PUSH=true
NO_CACHE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                        Docker Build and Push Script                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --tag TAG       Image tag (default: latest)
    --no-push       Build only, don't push to Docker Hub
    --no-cache      Build without using cache
    --help          Show this help message

ENVIRONMENT VARIABLES:
    DOCKER_HUB_USERNAME   Your Docker Hub username
    DOCKER_HUB_TOKEN      Your Docker Hub access token

EXAMPLES:
    # Build and push with latest tag
    ./$(basename "$0")
    
    # Build and push with specific tag
    ./$(basename "$0") --tag v1.0.0
    
    # Build only (no push)
    ./$(basename "$0") --no-push
    
    # Fresh build without cache
    ./$(basename "$0") --no-cache --tag fresh

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            TAG="$2"
            shift 2
            ;;
        --no-push)
            PUSH=false
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
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

# Check Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

# Get git info for labels
cd "$PROJECT_ROOT"
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Docker Build & Push                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Image:     $IMAGE_NAME:$TAG"
log_info "Commit:    $GIT_COMMIT"
log_info "Branch:    $GIT_BRANCH"
log_info "Build:     $BUILD_DATE"
echo ""

# Build the image
log_info "Building Docker image..."

docker build \
    $NO_CACHE \
    -f docker/Dockerfile \
    -t "$IMAGE_NAME:$TAG" \
    -t "$IMAGE_NAME:$GIT_COMMIT" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VERSION="$TAG" \
    --build-arg GIT_COMMIT="$GIT_COMMIT" \
    .

log_success "Image built: $IMAGE_NAME:$TAG"

# List image info
echo ""
log_info "Image details:"
docker images "$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
echo ""

# Push to Docker Hub
if [[ "$PUSH" == true ]]; then
    # Check credentials
    if [[ -z "${DOCKER_HUB_USERNAME:-}" ]]; then
        log_error "DOCKER_HUB_USERNAME not set"
        log_info "Set it with: export DOCKER_HUB_USERNAME=your-username"
        exit 1
    fi
    
    if [[ -z "${DOCKER_HUB_TOKEN:-}" ]]; then
        log_error "DOCKER_HUB_TOKEN not set"
        log_info "Set it with: export DOCKER_HUB_TOKEN=your-token"
        exit 1
    fi
    
    log_info "Logging in to Docker Hub..."
    echo "$DOCKER_HUB_TOKEN" | docker login -u "$DOCKER_HUB_USERNAME" --password-stdin
    
    log_info "Pushing $IMAGE_NAME:$TAG..."
    docker push "$IMAGE_NAME:$TAG"
    
    log_info "Pushing $IMAGE_NAME:$GIT_COMMIT..."
    docker push "$IMAGE_NAME:$GIT_COMMIT"
    
    docker logout
    
    log_success "Images pushed to Docker Hub!"
    echo ""
    echo "  🔗 https://hub.docker.com/r/$IMAGE_NAME"
    echo ""
else
    log_info "Skipping push (--no-push specified)"
fi

cat << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║                              Build Complete!                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

  📦 Image: $IMAGE_NAME:$TAG
  📦 Image: $IMAGE_NAME:$GIT_COMMIT
  
  To run locally:
    docker run -d -p 5000:5000 $IMAGE_NAME:$TAG
    
  To test:
    curl http://localhost:5000/health

EOF
