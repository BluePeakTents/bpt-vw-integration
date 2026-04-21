#!/usr/bin/env bash
# Elevation API connectivity smoke test.
#
# Usage:
#   GOOGLE_MAPS_ELEVATION_KEY=<key> ./tests/elevation-smoke-test.sh
#
# Tests a known coordinate (downtown Chicago, ~180m elevation).
# Passes if the API returns status OK with an elevation value.
#
# Failure modes to watch for:
#   REQUEST_DENIED   - key invalid, API not enabled, or IP/referrer restriction blocking
#   OVER_QUERY_LIMIT - quota exhausted
#   INVALID_REQUEST  - malformed request (should not happen with this script)

set -euo pipefail

if [[ -z "${GOOGLE_MAPS_ELEVATION_KEY:-}" ]]; then
  echo "FAIL: GOOGLE_MAPS_ELEVATION_KEY env var is not set." >&2
  echo "Run: GOOGLE_MAPS_ELEVATION_KEY=<your-key> $0" >&2
  exit 1
fi

LAT=41.8665
LNG=-87.6173

echo "Testing Elevation API at (${LAT}, ${LNG}) - downtown Chicago, expected ~180m..."
echo ""

RESPONSE=$(curl -sS "https://maps.googleapis.com/maps/api/elevation/json?locations=${LAT},${LNG}&key=${GOOGLE_MAPS_ELEVATION_KEY}")

echo "Raw response:"
echo "$RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q '"status"[[:space:]]*:[[:space:]]*"OK"'; then
  echo "PASS: Elevation API responded OK."
  exit 0
else
  echo "FAIL: Elevation API did not return OK status. See raw response above." >&2
  exit 1
fi
