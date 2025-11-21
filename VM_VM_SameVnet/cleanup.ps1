#Requires -Version 7.0

<#
.SYNOPSIS
    Cleanup script for VMs in same VNet deployment

.DESCRIPTION
    This script removes all resources created by the VMs in same VNet deployment.

.PARAMETER ResourceGroupName
    Name of the resource group to clean up (default: rg-vm-samevnet)

.PARAMETER Force
    Skip confirmation prompts and delete immediately

.PARAMETER WhatIf
    Show what would be deleted without actually deleting

.EXAMPLE
    .\cleanup.ps1

.EXAMPLE
    .\cleanup.ps1 -Force
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-samevnet",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White; "Magenta" = [ConsoleColor]::Magenta }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

Write-ColorOutput "🧹 VMs in Same VNet Cleanup Script" "Magenta"
Write-ColorOutput "==================================" "Magenta"

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName --output tsv
if ($rgExists -eq "false") {
    Write-ColorOutput "✅ Nothing to clean up - resource group doesn't exist" "Green"
    exit 0
}

# Show inventory
$resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
Write-ColorOutput "📦 Resource group found: $ResourceGroupName" "Cyan"
Write-ColorOutput "📊 Resources found: $($resources.Count)" "White"

if ($resources.Count -gt 0) {
    Write-ColorOutput "🗂️  Resource inventory:" "Cyan"
    foreach ($resource in $resources) {
        Write-ColorOutput "   • $($resource.type): $($resource.name)" "White"
    }
}

if ($WhatIf) {
    Write-ColorOutput "🔍 What-if mode: Resources above would be deleted" "Yellow"
    exit 0
}

if (-not $Force) {
    Write-ColorOutput "⚠️  WARNING: This will permanently delete ALL resources!" "Red"
    $response = Read-Host "Type 'yes' to confirm deletion"
    if ($response -ne "yes") {
        Write-ColorOutput "❌ Cleanup cancelled" "Yellow"
        exit 0
    }
}

Write-ColorOutput "🗑️  Deleting resource group: $ResourceGroupName" "Yellow"
az group delete --name $ResourceGroupName --yes --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Resource group deletion initiated successfully!" "Green"
    Write-ColorOutput "ℹ️  Deletion is running in the background" "Yellow"
} else {
    Write-ColorOutput "❌ Failed to delete resource group" "Red"
    exit 1
}