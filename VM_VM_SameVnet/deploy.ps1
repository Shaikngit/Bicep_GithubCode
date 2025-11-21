#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys VMs in same VNet Bicep template

.DESCRIPTION
    This script deploys multiple VMs (Windows/Linux) in the same Virtual Network.
    Supports cross-platform deployment with proper authentication options.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-vm-samevnet)

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER AdminUsername
    Administrator username for the VMs

.PARAMETER AdminPassword
    Administrator password for the VMs

.PARAMETER AllowedRdpSourceAddress
    Source IP address or CIDR range allowed for remote access

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake (default: Non-Overlake)

.PARAMETER OsType
    Operating system type - Windows or Linux (default: Windows)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!" -AllowedRdpSourceAddress "203.0.113.0/24"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!" -OsType "Linux" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-samevnet",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$AllowedRdpSourceAddress,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption = "Non-Overlake",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Windows", "Linux")]
    [string]$OsType = "Windows",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Helper functions
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    $allGood = $true
    
    try { $version = az version --output json 2>$null | ConvertFrom-Json; Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green" }
    catch { Write-ColorOutput "❌ Azure CLI not found" "Red"; $allGood = $false }
    
    try { $account = az account show --output json 2>$null | ConvertFrom-Json; Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green" }
    catch { Write-ColorOutput "❌ Not logged into Azure" "Red"; $allGood = $false }
    
    try { $version = az bicep version; Write-ColorOutput "✅ Bicep CLI version: $version" "Green" }
    catch { Write-ColorOutput "❌ Bicep CLI not found" "Red"; $allGood = $false }
    
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
    
    Write-ColorOutput "⚠️  This deployment will create multiple Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  Multiple VMs: ~$60-80/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Network and IPs: ~$8/month" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "vm-samevnet-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($SubscriptionId) { az account set --subscription $SubscriptionId }
    
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"; exit 1
    }
    
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", "main.bicep"
        "--name", $deploymentName
        "--parameters"
        "adminUsername=$AdminUsername"
        "adminPassword=$AdminPassword"
        "allowedRdpSourceAddress=$AllowedRdpSourceAddress"
        "vmSizeOption=$VmSizeOption"
        "osType=$OsType"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Deployment completed successfully!" "Green"
    } else {
        Write-ColorOutput "❌ Deployment failed" "Red"; exit 1
    }
}

# Main script
Write-ColorOutput "🖥️  VMs in Same VNet Deployment Script" "Cyan"
Write-ColorOutput "======================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VM SAME VNET DEPLOYMENT" "Cyan"
Write-ColorOutput "===========================" "Cyan"
Write-ColorOutput "• Multiple VMs in single VNet" "White"
Write-ColorOutput "• Cross-platform support (Windows/Linux)" "White"
Write-ColorOutput "• Shared networking infrastructure" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• OS Type: $OsType" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "===========================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"