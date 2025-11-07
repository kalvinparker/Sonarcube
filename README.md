# Sonarcube

Prototype repo for onboarding SonarCloud / SonarQube configuration, Quality Gates, and demo projects.

This repository contains:

- A tiny Node.js sample app
- GitHub Actions workflow to run SonarCloud analysis (requires `SONAR_TOKEN` secret)
- Documentation and Quality Gate templates

Usage

- Configure `SONAR_TOKEN` in repository secrets (SonarCloud token or SonarQube token)
- Update `sonar-project.properties` or workflow variables to match your organization/project

