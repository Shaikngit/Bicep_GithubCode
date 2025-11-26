#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Private Endpoint with Private Link Service and Internal Load Balancer

.DESCRIPTION
    This script deploys a Private Endpoint and Private Link Service setup with
    Internal Load Balancer and VMs for private connectivity demonstration.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-pe-pls-vm-intlb)

.PARAMETER Location
    Azure region for deployment (default: southeastasia)

.PARAMETER VmAdminUsername
    Administrator username for the VMs

.PARAMETER VmAdminPassword
    Administrator password for the VMs

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake

.PARAMETER AllowedRdpSourceAddress
    Source IP address or CIDR range allowed for RDP access

.PARAMETER UseCustomImage
    Use custom image from gallery (default: No)

.PARAMETER CustomImageResourceId
    Resource ID of custom image (optional)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -VmAdminUsername "azureuser" -VmAdminPassword "YourStrongPassword123!" -VmSizeOption "Non-Overlake" -AllowedRdpSourceAddress "203.0.113.0/24"

.EXAMPLE
    .\deploy.ps1 -VmAdminUsername "azureuser" -VmAdminPassword "YourStrongPassword123!" -VmSizeOption "Overlake" -AllowedRdpSourceAddress "203.0.113.0/24" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-pls-vm-intlb",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory=$true)]
    [string]$VmAdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$VmAdminPassword,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$true)]
    [string]$AllowedRdpSourceAddress,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Yes", "No")]
    [string]$UseCustomImage = "No",
    
    [Parameter(Mandatory=$false)]
    [string]$CustomImageResourceId = "",
    
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
    $hasUpper = $VmAdminPassword -cmatch '[A-Z]'
    $hasLower = $VmAdminPassword -cmatch '[a-z]'
    $hasDigit = $VmAdminPassword -match '\d'
    $hasSpecial = $VmAdminPassword -match '[^A-Za-z0-9]'
    $hasLength = $VmAdminPassword.Length -ge 12
    
    if ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $hasLength) {
        Write-ColorOutput "✅ Password meets complexity requirements" "Green"
    } else {
        Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character" "Red"
        $allGood = $false
    }
    
    return $allGood
}

function Get-PublicIP {
    try {
        $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
        return "$ip/32"
    } catch {
        return $AllowedRdpSourceAddress
    }
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  VMs (B2s): ~$30-40/month each" "Yellow"
    Write-ColorOutput "⚠️  Internal Load Balancer: ~$25/month" "Yellow"
    Write-ColorOutput "⚠️  Private Endpoints: ~$7/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Networks: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$75-85/month" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "pe-pls-vm-intlb-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($SubscriptionId) { az account set --subscription $SubscriptionId }
    
    # Auto-detect public IP if needed
    if ($AllowedRdpSourceAddress -eq "*" -or $AllowedRdpSourceAddress -eq "") {
        $publicIP = Get-PublicIP
        $AllowedRdpSourceAddress = $publicIP
        Write-ColorOutput "🌐 Auto-detected public IP: $AllowedRdpSourceAddress" "Cyan"
    }
    
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
        "vmAdminUsername=$VmAdminUsername"
        "vmAdminPassword=$VmAdminPassword"
        "vmSizeOption=$VmSizeOption"
        "allowedRdpSourceAddress=$AllowedRdpSourceAddress"
        "useCustomImage=$UseCustomImage"
    )
    
    if ($CustomImageResourceId -and $UseCustomImage -eq "Yes") {
        $deployCmd += @("customImageResourceId=$CustomImageResourceId")
    }
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "🏗️  Deploying Private Endpoint infrastructure..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 15-25 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            # Show outputs
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
        }
    } else {
        Write-ColorOutput "❌ Deployment failed" "Red"; exit 1
    }
}

# Main script
Write-ColorOutput "🔗 Private Endpoint + Private Link Service + Internal LB Deployment" "Cyan"
Write-ColorOutput "=================================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  PRIVATE ENDPOINT + PRIVATE LINK SERVICE LAB" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "• Private Endpoint for secure connectivity" "White"
Write-ColorOutput "• Private Link Service with Internal Load Balancer" "White"
Write-ColorOutput "• VMs behind Internal Load Balancer" "White"
Write-ColorOutput "• Virtual Networks with private connectivity" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Custom Image: $UseCustomImage" "White"
Write-ColorOutput "• Allowed RDP Source: $AllowedRdpSourceAddress" "White"
Write-ColorOutput "===============================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"