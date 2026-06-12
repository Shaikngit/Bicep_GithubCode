#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-mtu-lab-eastus2",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found in PATH. Install Azure CLI first."
}

az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI is not logged in. Run: az login"
}

if (-not $Force) {
    $confirmation = Read-Host "Delete resource group '$ResourceGroupName'? Type YES to continue"
    if ($confirmation -ne "YES") {
        Write-Host "Cleanup canceled."
        exit 0
    }
}

Write-Host "Deleting resource group '$ResourceGroupName'..."
az group delete --name $ResourceGroupName --yes --no-wait

Write-Host "Deletion started in background."
Write-Host "Check status with: az group show --name $ResourceGroupName"
