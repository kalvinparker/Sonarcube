# SonarCloud / SonarQube Setup and Initial Quality Gate

This document shows how to create an initial Quality Gate on SonarCloud and wire it to the `Sonarcube` project using the Sonar Web API. The repository includes a helper script and a manual workflow to run the creation when a valid `SONAR_TOKEN` is available.

IMPORTANT: This script and API calls require a SonarCloud token with Admin permissions in your Sonar organization.

## Quick checklist

- Create a SonarCloud organization for `kalvinparker` and note the organization key (typically `kalvinparker`).
- Create a project on SonarCloud (or allow the API to create it via the scanner). Set project key to `kalvinparker_Sonarcube` (or update `sonar-project.properties`).
- Add `SONAR_TOKEN` to repository secrets for `kalvinparker/Sonarcube` (Settings → Secrets → Actions).

## Example Quality Gate (what we'll create)

- Fail if any NEW code has a blocker or critical security vulnerability or bug.
- Fail if new code duplication > 3%.
- Fail if coverage on new code is below 80%.

## Create Quality Gate via SonarCloud API (helper script)

The repo includes `scripts/create_quality_gate.sh` which runs the necessary calls against SonarCloud. The workflow `.github/workflows/sonar-setup.yml` can run this script via the Actions runner if you dispatch the workflow.

Usage (locally):

```bash
export SONAR_TOKEN=your_sonar_token
./scripts/create_quality_gate.sh "kalvinparker_default_gate" "kalvinparker_Sonarcube"
```

What it does:
- Creates a named Quality Gate
- Adds conditions for new code (vulnerabilities, bugs, duplication, coverage)
- Attaches the gate to the project key you supply

If you prefer to run raw curl commands, the script prints those as well and displays responses.

## Validate metric keys

If a condition fails because of a metric name mismatch, you can list available metrics via API:

```bash
curl -u ${SONAR_TOKEN}: "https://sonarcloud.io/api/metrics/search"
```

## Demo / sample issues

To demonstrate PR decoration, the repository contains `src/buggy.js` with deliberate code smells and issues. Create a branch, open a PR targeting `main` and, once the scan runs, SonarCloud will annotate PRs with discovered issues.

## Troubleshooting

- If the API returns `403`, verify the token permissions and that it's a SonarCloud token (not a SonarQube token).
- If `metric` parameters appear invalid, query `/api/metrics/search` and adapt condition metric names.

## Security note

Do NOT commit tokens into the repository. Use GitHub Actions secrets. The helper script reads `SONAR_TOKEN` from environment only.
