#!/usr/bin/env bash
set -euo pipefail

# enforce_sonar_new_code.sh
# Usage: SONAR_TOKEN=<token> ./scripts/enforce_sonar_new_code.sh <project_key>
# This script queries SonarCloud for new-code metrics and fails if thresholds are violated.
# It is a workaround for organizations that cannot attach custom Quality Gates (paid feature).

API_BASE="https://sonarcloud.io/api"
PROJECT_KEY=${1:-kalvinparker_Sonarcube}

if [[ -z "${SONAR_TOKEN:-}" ]]; then
  echo "Error: SONAR_TOKEN is not set. Export it as an environment variable."
  exit 2
fi

# Metrics to fetch (new-code focused)
METRICS="new_vulnerabilities,new_bugs,new_code_smells,new_coverage,new_duplicated_lines_density,new_maintainability_rating,new_reliability_rating,new_security_rating,security_hotspots_reviewed"

echo "Fetching metrics for project ${PROJECT_KEY}"
RAW=$(curl -s -u "${SONAR_TOKEN}:" "${API_BASE}/measures/component?component=${PROJECT_KEY}&metricKeys=${METRICS}")

# Parse values with jq (requires jq available on runner)
values() {
  echo "$RAW" | jq -r --arg m "$1" '.component.measures[] | select(.metric==$m) | .value // "0"'
}

new_vuln=$(values new_vulnerabilities)
new_bugs=$(values new_bugs)
new_smells=$(values new_code_smells)
new_cov=$(values new_coverage)
new_dup=$(values new_duplicated_lines_density)
# Ratings are letters (A, B, C...); treat missing as null
new_maint=$(values new_maintainability_rating)
new_reli=$(values new_reliability_rating)
new_secu=$(values new_security_rating)
# security_hotspots_reviewed - Sonar may return percent (0-100) or count; we expect percent for this check
hotspots_reviewed=$(values security_hotspots_reviewed)

echo "new_vulnerabilities: $new_vuln"
echo "new_bugs: $new_bugs"
echo "new_code_smells: $new_smells"
echo "new_coverage: $new_cov"
echo "new_duplicated_lines_density: $new_dup"

echo "All new-code checks passed for ${PROJECT_KEY}."
fail=0

# Fail on any new vulnerabilities or bugs
if [[ "$new_vuln" != "0" && "$new_vuln" != "null" && -n "$new_vuln" ]]; then
  echo "Failure: new vulnerabilities > 0 ($new_vuln)"
  fail=1
fi
if [[ "$new_bugs" != "0" && "$new_bugs" != "null" && -n "$new_bugs" ]]; then
  echo "Failure: new bugs > 0 ($new_bugs)"
  fail=1
fi

# Duplicated lines on new code > 3%
if [[ -n "$new_dup" && "$new_dup" != "null" ]]; then
  if awk "BEGIN{exit !($new_dup > 3)}"; then
    echo "Failure: new duplicated lines density > 3% ($new_dup)"
    fail=1
  fi
else
  echo "Warning: new_duplicated_lines_density metric missing; skipping duplication check."
fi

# Coverage on new code < 80%
if [[ -n "$new_cov" && "$new_cov" != "null" ]]; then
  if awk "BEGIN{exit !($new_cov < 80)}"; then
    echo "Failure: new coverage < 80% ($new_cov)"
    fail=1
  fi
else
  echo "Warning: new_coverage metric missing; skipping coverage check."
fi

# Ratings: expected values like A, B, C... 'is worse than A' means anything != 'A' fails
check_rating() {
  local val="$1"; local name="$2"
  if [[ -n "$val" && "$val" != "null" ]]; then
    # Normalize to uppercase first char
    r=$(printf "%s" "$val" | awk '{print toupper(substr($0,1,1))}')
    if [[ "$r" != "A" ]]; then
      echo "Failure: $name rating is worse than A ($val)"
      fail=1
    fi
  else
    echo "Warning: $name metric missing; skipping $name check."
  fi
}

check_rating "$new_maint" "Maintainability"
check_rating "$new_reli" "Reliability"
check_rating "$new_secu" "Security"

# Security Hotspots Reviewed: expect 100%
if [[ -n "$hotspots_reviewed" && "$hotspots_reviewed" != "null" ]]; then
  # hotspots_reviewed may already be a percent integer; if it's a ratio, ensure numeric
  if awk "BEGIN{exit !($hotspots_reviewed < 100)}"; then
    echo "Failure: Security Hotspots Reviewed < 100% ($hotspots_reviewed)"
    fail=1
  fi
else
  echo "Warning: security_hotspots_reviewed metric missing; skipping hotspots reviewed check."
fi

if [[ $fail -eq 0 ]]; then
  echo "All new-code checks passed for ${PROJECT_KEY}."
  exit 0
else
  echo "One or more new-code checks failed for ${PROJECT_KEY}."
  exit 1
fi
