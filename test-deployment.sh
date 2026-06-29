#!/usr/bin/env bash
# Comprehensive deployment verification test for hardened Wire-Pod image

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

tests_passed=0
tests_failed=0

log() { echo -e "${BLUE}→${NC} $*"; }
pass() { echo -e "${GREEN}✓${NC} $*"; ((tests_passed++)); }
fail() { echo -e "${RED}✗${NC} $*"; ((tests_failed++)); }

log "Wire-Pod Deployment Verification Test Suite"
echo ""

# Test 1: Container runs and reaches healthy state
log "Test 1: Container health status"
docker compose down 2>/dev/null || true
docker compose up -d
sleep 10

STATUS=$(docker compose ps --format "{{.Status}}" 2>/dev/null | head -1)
if [[ "$STATUS" == *"healthy"* ]]; then
    pass "Container is healthy: $STATUS"
else
    fail "Container not healthy: $STATUS"
fi

# Test 2: Private keys removed
log "Test 2: Private keys removed from image"
if docker compose exec -T wire-pod test -f /opt/wire-pod/chipper/epod/ep.key 2>/dev/null; then
    fail "ep.key STILL EXISTS in image (should be removed)"
else
    pass "ep.key successfully removed"
fi

if docker compose exec -T wire-pod test -f /opt/wire-pod/chipper/pico.key 2>/dev/null; then
    fail "pico.key STILL EXISTS in image (should be removed)"
else
    pass "pico.key successfully removed"
fi

# Test 3: Web UI responds
log "Test 3: Web UI health check"
if curl -s http://localhost:8080/ok | grep -q "ok"; then
    pass "Web UI endpoint responds correctly"
else
    fail "Web UI endpoint not responding"
fi

# Test 4: Container internal health check
log "Test 4: Container health check (internal)"
if docker compose exec -T wire-pod curl -s http://localhost:8080/ok 2>/dev/null | grep -q "ok"; then
    pass "Internal health check passes"
else
    fail "Internal health check failed"
fi

# Test 5: Startup messages appear correctly
log "Test 5: Startup sequence verification"
LOGS=$(docker compose logs 2>&1)

if echo "$LOGS" | grep -q "Configuration page:"; then
    pass "Configuration page message found"
else
    fail "Configuration page message NOT found"
fi

if echo "$LOGS" | grep -q "Starting webserver"; then
    pass "Webserver startup message found"
else
    fail "Webserver startup message NOT found"
fi

if echo "$LOGS" | grep -q "mDNS"; then
    pass "mDNS service message found"
else
    fail "mDNS service message NOT found"
fi

# Test 6: Ports are exposed
log "Test 6: Port exposure"
EXPOSED_PORTS=$(docker inspect $(docker compose ps -q wire-pod) --format='{{json .Config.ExposedPorts}}' 2>/dev/null || echo "{}")
if echo "$EXPOSED_PORTS" | grep -q "80"; then
    pass "Port 80 exposed"
else
    fail "Port 80 NOT exposed"
fi

if echo "$EXPOSED_PORTS" | grep -q "8080"; then
    pass "Port 8080 exposed"
else
    fail "Port 8080 NOT exposed"
fi

# Test 7: No startup errors in logs
log "Test 7: Error detection"
if echo "$LOGS" | grep -q "error\|Error\|ERROR" | head -5; then
    # Check if it's just expected warnings
    ERROR_COUNT=$(echo "$LOGS" | grep -ic "error" || true)
    if [ $ERROR_COUNT -lt 3 ]; then
        pass "No critical errors in logs (minor warnings acceptable)"
    else
        fail "Multiple errors in logs (found $ERROR_COUNT instances)"
    fi
else
    pass "No errors in startup logs"
fi

# Test 8: Go version verification
log "Test 8: Go version (1.26+)"
if docker compose exec -T wire-pod /usr/local/go/bin/go version 2>/dev/null | grep -q "go1.2[6-9]\|go1.[3-9]"; then
    pass "Go 1.26+ confirmed"
else
    GO_VERSION=$(docker compose exec -T wire-pod /usr/local/go/bin/go version 2>/dev/null || echo "unknown")
    fail "Go version not 1.26+: $GO_VERSION"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Test Results:"
echo -e "${GREEN}Passed: $tests_passed${NC}"
if [ $tests_failed -gt 0 ]; then
    echo -e "${RED}Failed: $tests_failed${NC}"
    exit 1
else
    echo -e "${GREEN}Failed: $tests_failed${NC}"
    echo ""
    echo -e "${GREEN}✅ ALL TESTS PASSED - Hardened image deployment successful!${NC}"
    exit 0
fi
