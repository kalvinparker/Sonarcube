#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_quality_gate.sh <gate_name> <project_key>
# Requires: SONAR_TOKEN env var set (SonarCloud token with admin rights)

GATE_NAME=${1:-kalvinparker_default_gate}
PROJECT_KEY=${2:-kalvinparker_Sonarcube}
SONAR_ORG=${SONAR_ORG:-kalvinparker}
API_BASE="https://sonarcloud.io/api"

if [[ -z "${SONAR_TOKEN:-}" ]]; then
  echo "Error: SONAR_TOKEN environment variable is not set."
  exit 2
fi

echo "Creating quality gate: ${GATE_NAME}"

# 1) Create the gate
CREATED=$(curl -s -u "${SONAR_TOKEN}:" -X POST "${API_BASE}/qualitygates/create" --get --data-urlencode "name=${GATE_NAME}" --data-urlencode "organization=${SONAR_ORG}")
echo "Create response: $CREATED"
GATE_ID=$(echo "$CREATED" | jq -r '.id')
if [[ "$GATE_ID" == "null" || -z "$GATE_ID" ]]; then
  echo "Failed to create gate: $CREATED"
  exit 3
fi

echo "Created gate id: $GATE_ID"

# 2) Add conditions (metric keys: new_vulnerabilities, new_bugs, new_code_smells, new_coverage, new_duplicated_lines_density)
# Fail if any blocker/critical or if duplication > 3% or coverage < 80%

# Add condition: new vulnerabilities > 0
curl -s -u ${SONAR_TOKEN}: -X POST "${API_BASE}/qualitygates/create_condition?gateId=${GATE_ID}&metric=new_vulnerabilities&op=GT&error=0" | jq -r .
# Add condition: new bugs > 0
curl -s -u ${SONAR_TOKEN}: -X POST "${API_BASE}/qualitygates/create_condition?gateId=${GATE_ID}&metric=new_bugs&op=GT&error=0" | jq -r .
# Add condition: new_duplicated_lines_density > 3
curl -s -u ${SONAR_TOKEN}: -X POST "${API_BASE}/qualitygates/create_condition?gateId=${GATE_ID}&metric=new_duplicated_lines_density&op=GT&error=3" | jq -r . 
# Add condition: new_coverage < 80 (op=LT)
curl -s -u ${SONAR_TOKEN}: -X POST "${API_BASE}/qualitygates/create_condition?gateId=${GATE_ID}&metric=new_coverage&op=LT&error=80" | jq -r .

# 3) Set gate for project
echo "Attaching quality gate ${GATE_ID} to project ${PROJECT_KEY} (organization=${SONAR_ORG})"
ATTACH=$(curl -s -u "${SONAR_TOKEN}:" -X POST "${API_BASE}/qualitygates/select" --get --data-urlencode "projectKey=${PROJECT_KEY}" --data-urlencode "gateId=${GATE_ID}" --data-urlencode "organization=${SONAR_ORG}")
echo "Attach response: $ATTACH"

echo "Quality gate ${GATE_NAME} (${GATE_ID}) created and attached to ${PROJECT_KEY}."

echo "DONE"
