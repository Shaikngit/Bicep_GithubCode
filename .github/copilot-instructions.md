# Copilot Instructions — Bicep Lab Projects

This workspace contains Azure Bicep lab deployments. Every new project **must** follow the established conventions below.

Rules are split into component files under `.github/rules/`. Read **all** of them when generating a new project.

---

## Project Folder Structure

Each project lives in its own top-level folder and contains these files:

```
ProjectName/
├── main.bicep            # Primary Bicep template
├── deploy.ps1            # Deployment script (PowerShell 7+)
├── validate.ps1          # Pre-deployment validation script
├── cleanup.ps1           # Resource group deletion script
├── PROJECT_SUMMARY.md    # Detailed project summary
└── Readme.md             # Quick-start documentation
```

> **File naming**: Use `main.bicep` (not `azuredeploy.bicep`).

---

## Component Rules

| Rule file | Scope |
|-----------|-------|
| [rules/general.md](rules/general.md) | Default region, CLI policy, RG naming, folder structure |
| [rules/bicep-conventions.md](rules/bicep-conventions.md) | Parameters, variables, resources, networking, VMs, outputs, tags |
| [rules/deploy-script.md](rules/deploy-script.md) | `deploy.ps1` structure, helper functions, emoji output, error handling |
| [rules/validate-script.md](rules/validate-script.md) | `validate.ps1` checks, output formatting, exit codes |
| [rules/cleanup-script.md](rules/cleanup-script.md) | `cleanup.ps1` logging, Az module usage, deletion flow |
| [rules/documentation.md](rules/documentation.md) | `PROJECT_SUMMARY.md`, `Readme.md` sections, architecture diagrams |
