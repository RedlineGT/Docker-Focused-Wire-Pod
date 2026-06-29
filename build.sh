#!/usr/bin/env bash
# Wire-Pod Docker build script with advanced features
# Supports: multi-platform builds, BuildKit caching, SBOM generation, vulnerability scanning
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --prod              Build production image (Dockerfile.full, alpine-based)
#   --debug             Build debug image (Dockerfile.slim, ubuntu-based)
#   --platform ARCH     Target architecture: amd64, arm64, armv7 (default: native)
#   --push              Push to registry (requires REGISTRY_URL and credentials)
#   --scan              Scan image for vulnerabilities after build
#   --sbom              Generate and save SBOM (Software Bill of Materials)
#   --cache             Use BuildKit inline caching from registry
#   --help              Show this help message

set -euo pipefail

# Configuration
REGISTRY_URL="${REGISTRY_URL:-ghcr.io/kercre123}"
IMAGE_NAME="wire-pod"
BUILD_TYPE="prod"  # prod or debug
TARGET_PLATFORM="linux/$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
PUSH=false
SCAN=false
SBOM=false
USE_CACHE=false
COMMIT_SHA="${CI_COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo 'local')}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}→${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prod)
            BUILD_TYPE="prod"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --platform)
            TARGET_PLATFORM="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --scan)
            SCAN=true
            shift
            ;;
        --sbom)
            SBOM=true
            shift
            ;;
        --cache)
            USE_CACHE=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Select Dockerfile based on build type
if [ "$BUILD_TYPE" = "prod" ]; then
    DOCKERFILE="Dockerfile.full"
    IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:latest"
    CACHE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:buildcache-full"
else
    DOCKERFILE="Dockerfile.slim"
    IMAGE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:debug"
    CACHE_TAG="${REGISTRY_URL}/${IMAGE_NAME}:buildcache-slim"
fi

log "Building Wire-Pod ${BUILD_TYPE} image"
log "Dockerfile: $DOCKERFILE"
log "Target platform: $TARGET_PLATFORM"
log "Image tag: $IMAGE_TAG"
log "Commit: $COMMIT_SHA"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    error "docker not found. Install Docker to proceed."
    exit 1
fi

# Check if buildx is available for multi-platform builds
if [ "$TARGET_PLATFORM" != "native" ] && ! docker buildx version &>/dev/null; then
    error "docker buildx not found. Install Docker Buildx for multi-platform builds."
    exit 1
fi

# Build command
BUILD_CMD="docker build"
BUILD_ARGS="--build-arg COMMIT_SHA=$COMMIT_SHA"

# Add BuildKit inline caching if requested and registry is configured
if [ "$USE_CACHE" = true ]; then
    if [ -z "$REGISTRY_URL" ]; then
        warn "REGISTRY_URL not set. Skipping BuildKit cache."
    else
        log "Using BuildKit inline caching"
        BUILD_ARGS="$BUILD_ARGS --cache-from type=registry,ref=$CACHE_TAG"
        BUILD_ARGS="$BUILD_ARGS --cache-to type=registry,ref=$CACHE_TAG,mode=max"
    fi
fi

# Add SBOM generation if requested
if [ "$SBOM" = true ]; then
    log "SBOM generation enabled"
    BUILD_ARGS="$BUILD_ARGS --sbom=true"
fi

# Build the image
log "Starting build..."
eval "$BUILD_CMD $BUILD_ARGS -f $DOCKERFILE -t $IMAGE_TAG ."

if [ $? -eq 0 ]; then
    success "Image built successfully: $IMAGE_TAG"
else
    error "Build failed"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker images --filter "reference=$IMAGE_TAG" --format "{{.Size}}")
success "Image size: $IMAGE_SIZE"

# Scan for vulnerabilities if requested
if [ "$SCAN" = true ]; then
    log "Scanning image for vulnerabilities..."

    # Check if trivy is installed
    if ! command -v trivy &> /dev/null; then
        warn "Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
        warn "Skipping vulnerability scan."
    else
        # Run trivy scan with severity filter
        if trivy image --severity HIGH,CRITICAL "$IMAGE_TAG"; then
            success "Vulnerability scan passed (no HIGH/CRITICAL found)"
        else
            warn "Vulnerabilities found - review above. Image still created."
        fi
    fi
fi

# Generate SBOM if requested
if [ "$SBOM" = true ]; then
    log "Extracting SBOM from image..."

    SBOM_OUTPUT="wire-pod-${BUILD_TYPE}-sbom.json"

    if ! command -v syft &> /dev/null; then
        warn "Syft not installed. Install with: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"
        warn "Skipping SBOM extraction."
    else
        if syft "$IMAGE_TAG" -o json > "$SBOM_OUTPUT"; then
            success "SBOM saved to: $SBOM_OUTPUT"
        else
            error "Failed to generate SBOM"
        fi
    fi
fi

# Push to registry if requested
if [ "$PUSH" = true ]; then
    if [ -z "$REGISTRY_URL" ]; then
        error "REGISTRY_URL not set. Cannot push."
        exit 1
    fi

    log "Pushing image to registry..."
    if docker push "$IMAGE_TAG"; then
        success "Image pushed to: $IMAGE_TAG"
    else
        error "Push failed"
        exit 1
    fi
fi

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
success "Build complete!"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Image:        $IMAGE_TAG"
echo "Size:         $IMAGE_SIZE"
echo "Type:         $BUILD_TYPE"
echo "Dockerfile:   $DOCKERFILE"
echo ""

if [ "$BUILD_TYPE" = "prod" ]; then
    echo "To run:"
    echo "  docker compose up -d"
    echo ""
    echo "To push to registry:"
    echo "  docker push $IMAGE_TAG"
else
    echo "Debug image ready for testing."
    echo "To run:"
    echo "  docker compose -f compose.yaml up -d --build -f Dockerfile.slim"
fi

echo ""
