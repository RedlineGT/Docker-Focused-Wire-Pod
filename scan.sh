#!/usr/bin/env bash
# Wire-Pod security scanning script
# Scans built Docker images for vulnerabilities using Trivy
# Generates SBOM (Software Bill of Materials) for supply chain transparency
#
# Usage:
#   ./scan.sh [IMAGE] [OPTIONS]
#
# Examples:
#   ./scan.sh ghcr.io/kercre123/wire-pod:latest
#   ./scan.sh wire-pod:latest --severity HIGH,CRITICAL
#   ./scan.sh wire-pod:latest --format json
#   ./scan.sh wire-pod:latest --format sarif > results.sarif
#
# Options:
#   --severity LEVEL    Filter by severity: LOW, MEDIUM, HIGH, CRITICAL (default: all)
#   --format FORMAT     Output format: table, json, sarif, cyclonedx (default: table)
#   --sbom              Generate SBOM in addition to vulnerability scan
#   --fix               Suggest fixes for vulnerabilities
#   --config FILE       Use custom Trivy config file
#   --help              Show this help message

set -euo pipefail

# Configuration
IMAGE="${1:-}"
SEVERITY=""
FORMAT="table"
GENERATE_SBOM=false
SUGGEST_FIX=false
CONFIG=""

# Shift to remove IMAGE from arguments before parsing options
if [ -n "$IMAGE" ]; then
    shift
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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

info() {
    echo -e "${MAGENTA}ℹ${NC} $*"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --sbom)
            GENERATE_SBOM=true
            shift
            ;;
        --fix)
            SUGGEST_FIX=true
            shift
            ;;
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --help)
            grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
            exit 0
            ;;
        *)
            if [ -z "$IMAGE" ]; then
                IMAGE="$1"
            else
                error "Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [ -z "$IMAGE" ]; then
    error "No image specified. Usage: $0 IMAGE [OPTIONS]"
    echo ""
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
    exit 1
fi

# Check if Trivy is installed
if ! command -v trivy &> /dev/null; then
    error "Trivy is not installed. Please install it:"
    echo ""
    echo "  macOS (Homebrew):"
    echo "    brew install aquasecurity/trivy/trivy"
    echo ""
    echo "  Linux (Shell script):"
    echo "    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
    echo ""
    echo "  Or visit: https://github.com/aquasecurity/trivy/releases"
    exit 1
fi

log "Starting security scan of: $IMAGE"
echo ""

# Get image info
log "Pulling image metadata..."
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    error "Image not found: $IMAGE"
    error "Make sure the image is built or available locally: docker build -t $IMAGE ."
    exit 1
fi

IMAGE_ID=$(docker image inspect "$IMAGE" --format='{{.ID}}' | cut -d: -f2 | cut -c1-12)
IMAGE_SIZE=$(docker image inspect "$IMAGE" --format='{{.Size}}')
CREATED=$(docker image inspect "$IMAGE" --format='{{.Created}}')

echo "Image ID:    $IMAGE_ID"
echo "Size:        $(numfmt --to=iec-i --suffix=B $IMAGE_SIZE 2>/dev/null || echo $IMAGE_SIZE)"
echo "Created:     $CREATED"
echo ""

# Build Trivy command
TRIVY_CMD="trivy image"

# Add severity filter
if [ -n "$SEVERITY" ]; then
    TRIVY_CMD="$TRIVY_CMD --severity $SEVERITY"
    log "Filtering by severity: $SEVERITY"
fi

# Add format
TRIVY_CMD="$TRIVY_CMD --format $FORMAT"

# Add config if provided
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
    TRIVY_CMD="$TRIVY_CMD --config $CONFIG"
fi

# Run vulnerability scan
log "Running vulnerability scan..."
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if eval "$TRIVY_CMD $IMAGE"; then
    success "Vulnerability scan completed"
else
    # Trivy returns non-zero if vulnerabilities are found (expected)
    # Check exit code to determine if it's a real error vs. vulnerabilities found
    SCAN_EXIT=$?
    if [ $SCAN_EXIT -eq 1 ]; then
        # Exit 1 means vulnerabilities found (this is expected for images with CVEs)
        warn "Vulnerabilities were found (see above)"
    elif [ $SCAN_EXIT -ge 2 ]; then
        # Exit 2+ means actual error
        error "Scan failed with error code: $SCAN_EXIT"
        exit $SCAN_EXIT
    fi
fi

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Generate SBOM if requested
if [ "$GENERATE_SBOM" = true ]; then
    log "Generating SBOM (Software Bill of Materials)..."

    # Check if Syft is installed for better SBOM generation
    if command -v syft &> /dev/null; then
        SBOM_OUTPUT="wire-pod-sbom.json"
        SBOM_OUTPUT_SPDX="wire-pod-sbom.spdx.json"

        # Generate CycloneDX format (common in dependency scanning tools)
        if syft "$IMAGE" -o cyclonedx-json > "$SBOM_OUTPUT"; then
            success "SBOM (CycloneDX) saved to: $SBOM_OUTPUT"
            info "CycloneDX format is compatible with most SBOM tools and vulnerability trackers"
        fi

        # Also generate SPDX format (widely used standard)
        if syft "$IMAGE" -o spdx-json > "$SBOM_OUTPUT_SPDX"; then
            success "SBOM (SPDX) saved to: $SBOM_OUTPUT_SPDX"
            info "SPDX is an ISO standard for software bill of materials"
        fi
    else
        # Fallback: Use Trivy to generate SBOM
        SBOM_OUTPUT="wire-pod-sbom-trivy.json"
        trivy image --format cyclonedx "$IMAGE" > "$SBOM_OUTPUT"
        success "SBOM generated using Trivy: $SBOM_OUTPUT"
        warn "For better SBOM quality, install Syft: https://github.com/anchore/syft#installation"
    fi

    echo ""
fi

# Generate fix suggestions if requested
if [ "$SUGGEST_FIX" = true ]; then
    log "Analyzing potential fixes..."
    echo ""
    echo "Suggestion:"
    echo "  1. Check base image for security updates"
    echo "  2. Review Dockerfile.full and Dockerfile.slim for package versions"
    echo "  3. Consider using a minimal base image (Alpine is smaller but verify compatibility)"
    echo "  4. Run: docker build --pull --no-cache to get latest package versions"
    echo ""
fi

# Summary and recommendations
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
success "Scan report complete"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "Next steps:"
echo "  • Review vulnerabilities above"
echo "  • Verify if they affect Wire-Pod functionality"
echo "  • Consider updating base image: docker build --pull --no-cache"
echo "  • For CI/CD: integrate this scan into your pipeline"
echo ""

info "Security best practices:"
echo "  • Run full scan regularly (weekly/monthly)"
echo "  • Use SBOM for supply chain transparency"
echo "  • Set up automated alerts for new CVEs"
echo "  • Keep base images updated: alpine:latest, ubuntu:22.04"
echo ""
