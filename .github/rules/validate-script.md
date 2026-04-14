# Validate Script Conventions (`validate.ps1`)

## Parameters

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "main.bicep",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-<project-slug>-validate",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)
```

## Validation Checks

1. **Bicep syntax** — `az bicep build --file $TemplateFile --outdir temp`; clean up temp artifacts.
2. **ARM template validation** — create a temporary resource group, run `az deployment group validate`, then delete the temp RG with `--no-wait`.

## Output

- Use `Write-ColorOutput` with ✅/❌ per test.
- Print summary: `🎉 All validation tests passed!` or `❌ Some validation tests failed`.
- Exit code **0** on success, **1** on failure.

## CLI Rules

- **Always use `az` CLI** for all validation operations.
- **Never** use `Az` PowerShell module in validate scripts.
