# 🤖 Bicep Lab Agents — Quick Reference

## Agent Pipeline

```
                                    ┌─────────────────┐
                                    │   Bicep Lab      │  ← ENTRY POINT
                                    │   @bicep-lab     │
                                    │   (orchestrator) │
                                    └────────┬────────┘
                                             │
                              ┌──────────────┴──────────────┐
                              │ main.bicep exists?          │
                              ├──── NO ─────┐  ┌── YES ────┤
                              ▼              │  │           ▼
                   ┌─────────────────┐       │  │    ┌─────────────┐
                   │   Generator      │       │  │    │  (skip to   │
                   │  @bicep-generator│       │  │    │  validate)  │
                   └────────┬────────┘       │  │    └──────┬──────┘
                            │                │  │           │
                            ▼                │  │           │
                   ┌──────────────┐          │  │           │
                   │   Reviewer    │          │  │           │
                   │ @bicep-       │          │  │           │
                   │  reviewer     │          │  │           │
                   └──────┬───────┘          │  │           │
                          │                  │  │           │
                          └──────────────────┘  └───────────┘
                                    │
                                    ▼
                           ┌────────────────┐
                           │   Validator     │
                           │ @bicep-validator│
                           └───────┬────────┘
                                   │
                                   ▼
                           ┌───────────────┐
                           │   Deployer    │
                           │ @bicep-deployer│
                           └──────┬────────┘
                                  │ (on failure)
                           ┌──────▼────────┐
                           │ Troubleshooter│
                           │ @bicep-       │
                           │  troubleshooter│
                           └──────┬────────┘
                                  │
                                  ▼
                           ┌─────────────┐
                           │   Cleaner   │
                           │ @bicep-     │
                           │  cleaner    │
                           └─────────────┘

                   ┌──────────────┐
                   │   Updater    │  (standalone — runs anytime on older projects)
                   │ @bicep-      │
                   │  updater     │
                   └──────────────┘
```

## Agents

| # | Agent | Invoke With | Purpose | Tools |
|---|-------|-------------|---------|-------|
| 1 | **Bicep Lab** (orchestrator) | `@bicep-lab` | Entry point — checks if template exists, routes to generate or deploy flow | read, search, execute, edit, agent, todo |
| 2 | **Bicep Generator** | `@bicep-generator` | Scaffold a new lab project with all 6 required files (subagent only) | read, edit, search, execute |
| 3 | **Bicep Code Reviewer** | `@bicep-reviewer` | Read-only review against conventions. Reports violations, never edits. | read, search |
| 4 | **Bicep Lab Validator** | `@bicep-validator` | Pre-deployment checks: Bicep compilation, structure, convention compliance | read, search, execute |
| 5 | **Bicep Deployer** | `@bicep-deployer` | Run `deploy.ps1` with correct params, monitor output, handle errors | read, search, execute, todo |
| 6 | **Deployment Troubleshooter** | `@bicep-troubleshooter` | Diagnose failed deployments, parse errors, suggest fixes | read, search, execute, web |
| 7 | **Bicep Lab Cleaner** | `@bicep-cleaner` | Safely tear down lab resource groups with confirmation | read, search, execute |
| 8 | **Bicep Project Updater** | `@bicep-updater` | Upgrade older projects to current conventions | read, edit, search, execute |

## When to Use Which Agent

### New project from scratch
```
@bicep-lab → (auto-detects no template) → @bicep-generator → @bicep-reviewer → @bicep-validator → @bicep-deployer → @bicep-cleaner
```
Just use `@bicep-lab` — it detects there's no template and invokes the generator automatically, then continues through the pipeline.

### Already have a working Bicep template
```
@bicep-lab → (detects main.bicep exists) → @bicep-validator → @bicep-deployer → @bicep-cleaner
```
Same entry point. It sees the template exists and skips straight to validate → deploy.

### Want to skip the orchestrator
```
@bicep-deployer → @bicep-cleaner
```
You can invoke any agent directly if you know what you need.

### Deployment failed
```
@bicep-troubleshooter
```
Paste the error message or tell it which project failed. It runs `az deployment operation group list` to find the root cause and suggests fixes.

### Want to check code quality
```
@bicep-reviewer
```
Run anytime. It's read-only — reports convention violations without touching your code.

### Quick syntax check before deploying
```
@bicep-validator
```
Runs `az bicep build`, checks file structure, and verifies conventions.

### Older project needs updating
```
@bicep-updater
```
Points it at a legacy project (e.g., one using `azuredeploy.bicep` or missing `validate.ps1`). It identifies gaps, shows an upgrade plan, and applies changes after your approval.

### Done with lab, want to delete resources
```
@bicep-cleaner
```
Runs `cleanup.ps1` with safety prompts. Won't delete without your confirmation.

## Common Examples

| What you want to do | Command |
|---------------------|---------|
| Create a VM + NAT Gateway lab | `@bicep-lab Create a VM behind a NAT Gateway with a storage account` |
| Deploy an existing project | `@bicep-lab Deploy the SimpleVM-Linux project` |
| Review SimpleVM-Linux project | `@bicep-reviewer Review the SimpleVM-Linux project` |
| Validate before deploying | `@bicep-validator Validate the AzureAppGW project` |
| Deploy a lab | `@bicep-deployer Deploy SimpleVM-Linux with admin user azureuser` |
| Fix a failed deployment | `@bicep-troubleshooter The AzureAppGW deployment failed with SkuNotAvailable` |
| Clean up resources | `@bicep-cleaner Clean up rg-simple-linux-vm` |
| Modernize PEtoStrAccount | `@bicep-updater Update the PEtoStrAccount project to current conventions` |
