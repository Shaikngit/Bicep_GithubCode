# General Rules

- **Default Azure region**: `southeastasia`
- **No hardcoded credentials** — always use `@secure()` parameters.
- **No hardcoded locations** — always use `param location string = resourceGroup().location`.
- **Always use `az` CLI** for all deployment and resource operations — never use `Az` PowerShell module (`New-AzResourceGroupDeployment`, `New-AzResourceGroup`, etc.) in deploy or validate scripts.
- Cleanup scripts (`cleanup.ps1`) are the **only** exception — they use the `Az` PowerShell module (`Get-AzContext`, `Get-AzResourceGroup`, `Remove-AzResourceGroup`).
- Resource group naming convention: `rg-<project-slug>` (e.g., `rg-simple-linux-vm`, `rg-appgw-lab`).
- Keep all files for a project in **one flat folder** (no nested subfolders for infra).
