#Requires -Version 7.0

<#
.SYNOPSIS
    Cleanup script for Private Endpoint to SQL Server Database deployment

.DESCRIPTION
    This script removes all resources created by the Private Endpoint to SQL Server Database deployment.
    It provides options for complete cleanup or selective resource removal.

.PARAMETER ResourceGroupName
    Name of the resource group to clean up (default: rg-pe-sqlserverdb)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current subscription if not specified)

.PARAMETER Force
    Skip confirmation prompts and delete immediately

.PARAMETER WhatIf
    Show what would be deleted without actually deleting

.EXAMPLE
    .\cleanup.ps1

.EXAMPLE
    .\cleanup.ps1 -Force

.EXAMPLE
    .\cleanup.ps1 -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-sqlserverdb",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
        "Magenta" = [ConsoleColor]::Magenta
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    
    # Test Azure CLI
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not found. Please install Azure CLI." "Red"
        return $false
    }
    
    # Test Azure login
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name) ($($account.id))" "Green"
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'." "Red"
        return $false
    }
    
    return $true
}

function Get-ResourceGroupInfo {
    Write-ColorOutput "📦 Checking resource group: $ResourceGroupName" "Cyan"
    
    $rgExists = az group exists --name $ResourceGroupName --output tsv
    if ($rgExists -eq "true") {
        Write-ColorOutput "✅ Resource group found" "Green"
        
        # Get resource count
        $resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        Write-ColorOutput "📊 Resources found: $($resources.Count)" "White"
        
        if ($resources.Count -gt 0) {
            Write-ColorOutput "🗂️  Resource inventory:" "Cyan"
            foreach ($resource in $resources) {
                Write-ColorOutput "   • $($resource.type): $($resource.name)" "White"
            }
        }
        
        return $true
    } else {
        Write-ColorOutput "ℹ️  Resource group '$ResourceGroupName' does not exist" "Yellow"
        return $false
    }
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput "⚠️  WARNING: This will permanently delete ALL resources in the resource group!" "Red"
    Write-ColorOutput "⚠️  This includes SQL Server, database, and all data!" "Red"
    Write-ColorOutput "⚠️  This action cannot be undone!" "Red"
    Write-ColorOutput "⚠️  Resource Group: $ResourceGroupName" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Are you sure you want to delete all resources? Type 'yes' to confirm"
    return ($response -eq "yes")
}

function Start-Cleanup {
    if ($WhatIf) {
        Write-ColorOutput "🔍 What-if mode: Showing resources that would be deleted..." "Cyan"
        az group delete --name $ResourceGroupName --yes --dry-run
        Write-ColorOutput "ℹ️  No resources were actually deleted (what-if mode)" "Yellow"
        return
    }
    
    Write-ColorOutput "🗑️  Starting resource cleanup..." "Cyan"
    Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
    
    # Delete resource group (this deletes all resources within it)
    Write-ColorOutput "🗑️  Deleting resource group: $ResourceGroupName" "Yellow"
    az group delete --name $ResourceGroupName --yes --no-wait
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Resource group deletion initiated successfully!" "Green"
        Write-ColorOutput "ℹ️  Deletion is running in the background and may take 10-15 minutes to complete." "Yellow"
        Write-ColorOutput "ℹ️  You can check the status in the Azure portal or run:" "Cyan"
        Write-ColorOutput "   az group show --name $ResourceGroupName --query 'properties.provisioningState'" "White"
    } else {
        Write-ColorOutput "❌ Failed to delete resource group" "Red"
        exit 1
    }
}

function Show-CleanupStatus {
    Write-ColorOutput "📊 Cleanup Status Check" "Cyan"
    Write-ColorOutput "======================" "Cyan"
    
    $rgExists = az group exists --name $ResourceGroupName --output tsv
    if ($rgExists -eq "false") {
        Write-ColorOutput "✅ Resource group has been completely deleted" "Green"
    } else {
        $state = az group show --name $ResourceGroupName --query "properties.provisioningState" --output tsv 2>$null
        if ($state -eq "Deleting") {
            Write-ColorOutput "⏳ Resource group deletion in progress..." "Yellow"
        } else {
            Write-ColorOutput "ℹ️  Resource group state: $state" "Yellow"
        }
    }
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🧹 Private Endpoint to SQL Server DB Cleanup Script" "Magenta"
Write-ColorOutput "=================================================" "Magenta"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"

# Check if resource group exists and show inventory
$rgExists = Get-ResourceGroupInfo

if (-not $rgExists) {
    Write-ColorOutput "✅ Nothing to clean up - resource group doesn't exist" "Green"
    exit 0
}

Write-ColorOutput "" "White"

# Get confirmation unless in WhatIf mode
if (-not $WhatIf -and -not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Cleanup cancelled by user" "Yellow"
    exit 0
}

# Perform cleanup
Start-Cleanup

# Show final status
if (-not $WhatIf) {
    Write-ColorOutput "" "White"
    Write-ColorOutput "⏰ End time: $(Get-Date)" "White"
    Write-ColorOutput "" "White"
    Show-CleanupStatus
    Write-ColorOutput "" "White"
    Write-ColorOutput "🎉 Cleanup script completed!" "Green"
}