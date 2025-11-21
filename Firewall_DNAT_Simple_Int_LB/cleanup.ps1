#Requires -Version 7.0

<#
.SYNOPSIS
    Cleanup script for Azure Firewall DNAT + Internal LB deployment

.DESCRIPTION
    This script removes all resources created by the Firewall DNAT deployment.
    WARNING: This is a high-cost deployment - ensure you want to delete everything.

.PARAMETER ResourceGroupName
    Name of the resource group to clean up (default: rg-firewall-dnat-intlb)

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
    [string]$ResourceGroupName = "rg-firewall-dnat-intlb",
    
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

Write-ColorOutput "🧹 Firewall DNAT + Internal LB Cleanup Script" "Magenta"
Write-ColorOutput "=============================================" "Magenta"

# Check prerequisites
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
} catch {
    Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'." "Red"
    exit 1
}

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName --output tsv
if ($rgExists -eq "false") {
    Write-ColorOutput "✅ Nothing to clean up - resource group doesn't exist" "Green"
    exit 0
}

# Show comprehensive inventory
Write-ColorOutput "📦 Analyzing resource group: $ResourceGroupName" "Cyan"
$resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
Write-ColorOutput "📊 Resources found: $($resources.Count)" "White"

if ($resources.Count -gt 0) {
    Write-ColorOutput "🗂️  Detailed resource inventory:" "Cyan"
    
    # Group resources by type for better overview
    $resourcesByType = $resources | Group-Object type | Sort-Object Name
    foreach ($group in $resourcesByType) {
        Write-ColorOutput "   📁 $($group.Name) ($($group.Count) resources):" "Yellow"
        foreach ($resource in $group.Group) {
            Write-ColorOutput "      • $($resource.name)" "White"
        }
    }
    
    # Calculate estimated monthly savings
    $firewalls = ($resources | Where-Object { $_.type -like "*azureFirewalls*" }).Count
    $vms = ($resources | Where-Object { $_.type -like "*virtualMachines*" }).Count
    $bastion = ($resources | Where-Object { $_.type -like "*bastionHosts*" }).Count
    $natgw = ($resources | Where-Object { $_.type -like "*natGateways*" }).Count
    
    $estimatedSavings = ($firewalls * 912) + ($vms * 35) + ($bastion * 140) + ($natgw * 45) + 25  # LB cost
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "💰 Estimated monthly cost savings after cleanup: ~$${estimatedSavings}" "Green"
}

if ($WhatIf) {
    Write-ColorOutput "🔍 What-if mode: All resources above would be deleted" "Yellow"
    Write-ColorOutput "ℹ️  No resources were actually deleted (what-if mode)" "Yellow"
    exit 0
}

if (-not $Force) {
    Write-ColorOutput "⚠️  WARNING: This will permanently delete ALL resources in the resource group!" "Red"
    Write-ColorOutput "⚠️  This includes expensive infrastructure like Azure Firewall, Bastion, and VMs!" "Red"
    Write-ColorOutput "⚠️  This action cannot be undone!" "Red"
    Write-ColorOutput "⚠️  Resource Group: $ResourceGroupName" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Are you absolutely sure you want to delete all resources? Type 'DELETE' to confirm"
    if ($response -ne "DELETE") {
        Write-ColorOutput "❌ Cleanup cancelled - confirmation not received" "Yellow"
        exit 0
    }
}

Write-ColorOutput "🗑️  Starting comprehensive resource cleanup..." "Cyan"
Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
Write-ColorOutput "🗑️  Deleting resource group: $ResourceGroupName" "Yellow"

az group delete --name $ResourceGroupName --yes --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Resource group deletion initiated successfully!" "Green"
    Write-ColorOutput "ℹ️  Deletion is running in the background and may take 15-30 minutes" "Yellow"
    Write-ColorOutput "ℹ️  This includes time for Azure Firewall and other complex resources" "Yellow"
    Write-ColorOutput "ℹ️  Check status with: az group show --name $ResourceGroupName --query 'properties.provisioningState'" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "💰 You will stop incurring costs once deletion completes!" "Green"
} else {
    Write-ColorOutput "❌ Failed to delete resource group" "Red"
    exit 1
}

Write-ColorOutput "🎉 Cleanup script completed!" "Green"