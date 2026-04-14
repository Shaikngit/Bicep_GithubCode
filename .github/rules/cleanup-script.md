# Cleanup Script Conventions (`cleanup.ps1`)

## Parameters

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)
```

## Logging

Use `Write-Log` (not `Write-ColorOutput`):

```powershell
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}
```

## Cleanup Flow

```
1. Test-AzureLogin (using Get-AzContext / Connect-AzAccount)
2. Check resource group exists (Get-AzResourceGroup)
3. List all resources in the group
4. Prompt for confirmation (unless -Force)
5. Remove-AzResourceGroup -Force -AsJob
6. Optional: wait and report duration
```

## CLI Rules

- Cleanup scripts are the **only** exception — they use the `Az` PowerShell module (`Get-AzContext`, `Get-AzResourceGroup`, `Remove-AzResourceGroup`).
