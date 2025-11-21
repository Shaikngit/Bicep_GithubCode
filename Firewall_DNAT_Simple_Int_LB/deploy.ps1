#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Azure Firewall DNAT with Simple Internal Load Balancer

.DESCRIPTION
    This script deploys a comprehensive networking lab with Azure Firewall DNAT rules,
    hub-spoke VNet architecture, Internal Load Balancer, NAT Gateway, and Bastion.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-firewall-dnat-intlb)

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER AdminUsername
    Administrator username for the VMs

.PARAMETER AdminPassword
    Administrator password for the VMs

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake (default: Non-Overlake)

.PARAMETER VmNamePrefix
    Prefix for VM names (default: BackendVM)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!" -VmSizeOption "Overlake" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-firewall-dnat-intlb",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$false)]
    [string]$VmNamePrefix = "BackendVM",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{
        "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White
    }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    $allGood = $true
    
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
    } catch {
        Write-ColorOutput "❌ Azure CLI not found" "Red"; $allGood = $false
    }
    
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name)" "Green"
    } catch {
        Write-ColorOutput "❌ Not logged into Azure" "Red"; $allGood = $false
    }
    
    try {
        $version = az bicep version
        Write-ColorOutput "✅ Bicep CLI version: $version" "Green"
    } catch {
        Write-ColorOutput "❌ Bicep CLI not found" "Red"; $allGood = $false
    }
    
    # Password validation
    $hasUpper = $AdminPassword -cmatch '[A-Z]'
    $hasLower = $AdminPassword -cmatch '[a-z]'
    $hasDigit = $AdminPassword -match '\d'
    $hasSpecial = $AdminPassword -match '[^A-Za-z0-9]'
    $hasLength = $AdminPassword.Length -ge 12
    
    if ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $hasLength) {
        Write-ColorOutput "✅ Password meets complexity requirements" "Green"
    } else {
        Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character" "Red"
        $allGood = $false
    }
    
    return $allGood
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create multiple Azure resources and may incur significant costs." "Yellow"
    Write-ColorOutput "⚠️  Azure Firewall Standard: ~$1.25/hour (~$912/month)" "Yellow"
    Write-ColorOutput "⚠️  Multiple VMs (B2s): ~$30-40/month each" "Yellow"
    Write-ColorOutput "⚠️  NAT Gateway: ~$45/month" "Yellow"
    Write-ColorOutput "⚠️  Bastion: ~$140/month" "Yellow"
    Write-ColorOutput "⚠️  Load Balancer: ~$25/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$1200+/month" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Do you want to continue with this high-cost deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "firewall-dnat-intlb-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $templateFile = "main.bicep"
    
    if ($SubscriptionId) {
        Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
        az account set --subscription $SubscriptionId
    }
    
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"; exit 1
    }
    
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", $templateFile
        "--name", $deploymentName
        "--parameters"
        "adminUsername=$AdminUsername"
        "adminPassword=$AdminPassword"
        "vmSizeOption=$VmSizeOption"
        "vmNamePrefix=$VmNamePrefix"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "📄 Template: $templateFile" "White"
        Write-ColorOutput "📍 Target: Resource Group '$ResourceGroupName'" "White"
        Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
        Write-ColorOutput "🏗️  Deploying complex networking infrastructure..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 45-60 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        if ($WhatIf) {
            Write-ColorOutput "✅ What-if analysis completed successfully!" "Green"
        } else {
            Write-ColorOutput "✅ Deployment completed successfully!" "Green"
            Write-ColorOutput "⏰ End time: $(Get-Date)" "White"
            
            # Show deployment outputs
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
        }
    } else {
        Write-ColorOutput "❌ Deployment failed with exit code: $LASTEXITCODE" "Red"
        Write-ColorOutput "💡 Check the Azure portal for detailed error information" "Yellow"
        Write-ColorOutput "💡 Deployment name: $deploymentName" "Yellow"
        exit 1
    }
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔥 Azure Firewall DNAT + Internal LB Deployment Script" "Cyan"
Write-ColorOutput "======================================================" "Cyan"

if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  FIREWALL DNAT + INTERNAL LOAD BALANCER LAB" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "This deployment creates a comprehensive networking lab:" "White"
Write-ColorOutput "• Azure Firewall with DNAT rules" "White"
Write-ColorOutput "• Hub-Spoke VNet architecture with peering" "White"
Write-ColorOutput "• Internal Load Balancer for backend VMs" "White"
Write-ColorOutput "• NAT Gateway for outbound connectivity" "White"
Write-ColorOutput "• Azure Bastion for secure VM access" "White"
Write-ColorOutput "• Multiple VMs for testing" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Primary Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• VM Name Prefix: $VmNamePrefix" "White"
if ($WhatIf) {
    Write-ColorOutput "• Deployment Type: What-If Analysis" "Yellow"
} else {
    Write-ColorOutput "• Deployment Type: Full Deployment" "White"
    Write-ColorOutput "• Estimated Duration: 45-60 minutes" "White"
}
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "" "White"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"
    exit 1
}

Start-Deployment
Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Script execution completed!" "Green"