#Requires -Version 7.0

<#
.SYNOPSIS
    Cleans up the VMSS Cross-Region deployment

.DESCRIPTION
    This script removes all resources created by the deploy.ps1 script by deleting the resource group.

.PARAMETER ResourceGroupName
    Name of the resource group to delete (default: rg-vmss-crossregion)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\cleanup.ps1

.EXAMPLE
    .\cleanup.ps1 -Force

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName "my-custom-rg" -Force
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vmss-crossregion",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
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
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-AzureCLI {
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not found. Please install Azure CLI." "Red"
        return $false
    }
}

function Test-AzureLogin {
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'." "Red"
        return $false
    }
}

function Test-ResourceGroupExists {
    param([string]$RgName)
    
    $exists = az group exists --name $RgName 2>$null
    return $exists -eq "true"
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput "⚠️  This will permanently delete all resources in resource group: $ResourceGroupName" "Yellow"
    Write-ColorOutput "⚠️  This action cannot be undone!" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Are you sure you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🧹 VMSS Cross-Region Cleanup Script" "Cyan"
Write-ColorOutput "=====================================" "Cyan"

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"

if (-not (Test-AzureCLI)) {
    exit 1
}

if (-not (Test-AzureLogin)) {
    exit 1
}

# Check if resource group exists
Write-ColorOutput "🔍 Checking if resource group exists: $ResourceGroupName" "Cyan"

if (-not (Test-ResourceGroupExists -RgName $ResourceGroupName)) {
    Write-ColorOutput "⚠️  Resource group '$ResourceGroupName' does not exist. Nothing to clean up." "Yellow"
    exit 0
}

Write-ColorOutput "✅ Resource group '$ResourceGroupName' found." "Green"

# List resources that will be deleted
Write-ColorOutput "" "White"
Write-ColorOutput "📋 Resources in resource group '$ResourceGroupName':" "Cyan"
az resource list --resource-group $ResourceGroupName --query "[].{Name:name, Type:type}" --output table

Write-ColorOutput "" "White"

# Get user confirmation
if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Cleanup cancelled by user." "Red"
    exit 1
}

# Delete resource group
Write-ColorOutput "" "White"
Write-ColorOutput "🗑️  Deleting resource group: $ResourceGroupName" "Cyan"
Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
Write-ColorOutput "⏳ This may take several minutes..." "Yellow"

az group delete --name $ResourceGroupName --yes --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Resource group deletion initiated successfully!" "Green"
    Write-ColorOutput "💡 The deletion is running in the background." "Yellow"
    Write-ColorOutput "💡 You can check the status in the Azure portal or run:" "Yellow"
    Write-ColorOutput "   az group show --name $ResourceGroupName --query 'properties.provisioningState'" "White"
} else {
    Write-ColorOutput "❌ Failed to initiate resource group deletion" "Red"
    exit 1
}

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Cleanup script completed!" "Green"
