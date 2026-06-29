#!/usr/bin/env bash
# Security Audit Trend Tracker
# Monitors CVE counts across builds and tracks remediation progress
# Usage: ./security-audit.sh [image]

set -euo pipefail

IMAGE="${1:-ghcr.io/kercre123/wire-pod:latest}"
AUDIT_DIR=".security-audits"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REPORT_FILE="${AUDIT_DIR}/${TIMESTAMP}-audit.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

# Create audit directory if needed
mkdir -p "${AUDIT_DIR}"

log "Running security audit on: $IMAGE"
log "Timestamp: $TIMESTAMP"
echo ""

# Check if Trivy is installed
if ! command -v trivy &>/dev/null; then
    error "Trivy is not installed"
    exit 1
fi

# Run Trivy scan with JSON output
log "Scanning with Trivy..."
trivy image "${IMAGE}" --format json --output "${REPORT_FILE}" 2>&1 | grep -E "(Scanning|Generating|Found)" || true

# Extract vulnerability counts
if [ -f "${REPORT_FILE}" ]; then
    RESULTS=$(jq '.Results[0].Vulnerabilities // []' "${REPORT_FILE}")

    CRITICAL=$(echo "$RESULTS" | jq 'map(select(.Severity=="CRITICAL")) | length')
    HIGH=$(echo "$RESULTS" | jq 'map(select(.Severity=="HIGH")) | length')
    MEDIUM=$(echo "$RESULTS" | jq 'map(select(.Severity=="MEDIUM")) | length')
    LOW=$(echo "$RESULTS" | jq 'map(select(.Severity=="LOW")) | length')
    UNKNOWN=$(echo "$RESULTS" | jq 'map(select(.Severity=="UNKNOWN")) | length')
    TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW + UNKNOWN))

    # Check for secrets
    SECRETS=$(jq '.Results[1].Misconfigurations // [] | map(select(.Type=="secret")) | length' "${REPORT_FILE}" 2>/dev/null || echo "0")

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}CVE Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    [ $CRITICAL -gt 0 ] && echo -e "${RED}CRITICAL: $CRITICAL${NC}" || echo -e "${GREEN}CRITICAL: $CRITICAL${NC}"
    [ $HIGH -gt 0 ] && echo -e "${RED}HIGH:      $HIGH${NC}" || echo -e "${GREEN}HIGH:      $HIGH${NC}"
    [ $MEDIUM -gt 0 ] && echo -e "${YELLOW}MEDIUM:    $MEDIUM${NC}" || echo -e "${GREEN}MEDIUM:    $MEDIUM${NC}"
    [ $LOW -gt 0 ] && echo -e "${YELLOW}LOW:       $LOW${NC}" || echo -e "${GREEN}LOW:       $LOW${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    [ $TOTAL -gt 0 ] && echo -e "${RED}TOTAL:     $TOTAL${NC}" || echo -e "${GREEN}TOTAL:     $TOTAL${NC}"
    [ $SECRETS -gt 0 ] && echo -e "${RED}SECRETS:   $SECRETS${NC}" || echo -e "${GREEN}SECRETS:   $SECRETS${NC}"

    echo ""
    echo -e "${GREEN}✓ Report saved: $REPORT_FILE${NC}"
    echo ""

    # Show comparison with previous audit
    PREV_REPORT=$(ls -t "${AUDIT_DIR}"/*-audit.json 2>/dev/null | head -2 | tail -1)
    if [ -n "$PREV_REPORT" ] && [ "$PREV_REPORT" != "$REPORT_FILE" ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Comparison with previous audit${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        PREV_RESULTS=$(jq '.Results[0].Vulnerabilities // []' "${PREV_REPORT}")
        PREV_CRITICAL=$(echo "$PREV_RESULTS" | jq 'map(select(.Severity=="CRITICAL")) | length')
        PREV_HIGH=$(echo "$PREV_RESULTS" | jq 'map(select(.Severity=="HIGH")) | length')
        PREV_MEDIUM=$(echo "$PREV_RESULTS" | jq 'map(select(.Severity=="MEDIUM")) | length')
        PREV_TOTAL=$((PREV_CRITICAL + PREV_HIGH + PREV_MEDIUM))

        DELTA_CRITICAL=$((CRITICAL - PREV_CRITICAL))
        DELTA_HIGH=$((HIGH - PREV_HIGH))
        DELTA_MEDIUM=$((MEDIUM - PREV_MEDIUM))
        DELTA_TOTAL=$((TOTAL - PREV_TOTAL))

        format_delta() {
            if [ "$1" -lt 0 ]; then
                echo -e "${GREEN}$1 ✓${NC}"
            elif [ "$1" -gt 0 ]; then
                echo -e "${RED}+$1${NC}"
            else
                echo -e "${BLUE}→ $1${NC}"
            fi
        }

        echo "CRITICAL: $(format_delta $DELTA_CRITICAL) (was $PREV_CRITICAL)"
        echo "HIGH:     $(format_delta $DELTA_HIGH) (was $PREV_HIGH)"
        echo "MEDIUM:   $(format_delta $DELTA_MEDIUM) (was $PREV_MEDIUM)"
        echo "TOTAL:    $(format_delta $DELTA_TOTAL) (was $PREV_TOTAL)"
        echo ""

        if [ $DELTA_TOTAL -lt 0 ]; then
            success "Security improved by $((DELTA_TOTAL * -1)) vulnerabilities!"
        elif [ $DELTA_TOTAL -gt 0 ]; then
            warn "Security degraded by $DELTA_TOTAL vulnerabilities"
        else
            log "No change in vulnerability count"
        fi
    fi

    # List critical CVEs
    if [ $CRITICAL -gt 0 ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}CRITICAL CVEs - Require Immediate Action${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        jq '.Results[0].Vulnerabilities[] | select(.Severity=="CRITICAL") | "\(.VulnerabilityID): \(.Title)"' -r "${REPORT_FILE}" | while read -r cve; do
            echo "  $cve"
        done
        echo ""
    fi

    # Summary for trending
    summary_json=$(jq -n \
        --arg timestamp "$TIMESTAMP" \
        --arg image "$IMAGE" \
        --argjson critical "$CRITICAL" \
        --argjson high "$HIGH" \
        --argjson medium "$MEDIUM" \
        --argjson low "$LOW" \
        --argjson total "$TOTAL" \
        --argjson secrets "$SECRETS" \
        '{timestamp: $timestamp, image: $image, critical: $critical, high: $high, medium: $medium, low: $low, total: $total, secrets: $secrets}')

    # Append to trend file
    TREND_FILE="${AUDIT_DIR}/trend.jsonl"
    echo "$summary_json" >> "$TREND_FILE"
    success "Trend data saved to: $TREND_FILE"

else
    error "Failed to generate security report"
    exit 1
fi

echo ""
log "Security audit complete"
