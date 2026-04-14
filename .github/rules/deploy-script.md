# Deploy Script Conventions (`deploy.ps1`)

## Header

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys <Project Name> Bicep template

.DESCRIPTION
    <Detailed description of what gets deployed, including resource list and purpose.>

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-<project-slug>)

.PARAMETER Location
    Azure region (default: southeastasia)

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd!"
#>
```

## Standard Parameters

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-<project-slug>",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,

    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,

    # Add project-specific params here with ValidateSet where applicable

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)
```

> Default location is **southeastasia** unless the project requires a different region.

## Required Helper Functions

Every deploy script must include:

| Function | Purpose |
|----------|---------|
| `Write-ColorOutput` | Colored console output (Red, Green, Yellow, Cyan, White) |
| `Test-AzureCLI` | Verify `az` is installed |
| `Test-AzureLogin` | Verify active Azure session |
| `Test-BicepCLI` | Verify/install Bicep CLI |
| `Test-PasswordComplexity` | 12+ chars, upper, lower, digit, special |
| `Test-SSHKeyFormat` | _(Linux only)_ validate SSH public key |
| `Test-Prerequisites` | Orchestrate all checks above |
| `Get-UserConfirmation` | Show cost estimate, prompt unless `-Force` |
| `Start-Deployment` | Create RG, run `az deployment group create` |

## Console Output Style

Use emoji + color prefixes consistently:

```
🔍  — checking / searching (Cyan)
✅  — success (Green)
❌  — failure (Red)
⚠️   — warning / cost notice (Yellow)
📦  — creating resources (Cyan)
🎯  — setting targets (Cyan)
🚀  — starting deployment (Cyan)
🎉  — all passed / done (Green)
```

## Deployment Flow

```
1. Test-Prerequisites  →  exit 1 on failure
2. Get-UserConfirmation (show estimated monthly cost)  →  exit 0 if declined
3. Start-Deployment:
   a. Set subscription (if param provided)
   b. az group create --name $RG --location $Location --output none
   c. az deployment group create ... --parameters key=value
   d. Check $LASTEXITCODE → print success or failure
```

## Error Handling

- Check `$LASTEXITCODE -ne 0` after every `az` command.
- Use `try/catch` for PowerShell cmdlet calls.
- Redirect stderr with `2>$null` when output is parsed.

## CLI Rules

- **Always use `az` CLI** for all deployment and resource operations.
- **Never** use `Az` PowerShell module (`New-AzResourceGroupDeployment`, `New-AzResourceGroup`, etc.) in deploy scripts.
