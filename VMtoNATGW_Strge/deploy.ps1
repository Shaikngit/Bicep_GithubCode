#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys VM with NAT Gateway and Storage Account using modular architecture

.DESCRIPTION
    This script deploys a Windows VM with NAT Gateway for outbound internet connectivity
    and a Storage Account using modular Bicep templates.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-vm-natgw-storage)

.PARAMETER Location
    Azure region for deployment (default: southeastasia)

.PARAMETER AdminPassword
    Administrator password for the VM

.PARAMETER AdminUsername
    Administrator username for the VM

.PARAMETER AllowedRdpSourceAddress
    Source IP address or CIDR range allowed for RDP access

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake

.PARAMETER UseCustomImage
    Use custom image from gallery (default: No)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -AllowedRdpSourceAddress "203.0.113.0/24" -VmSizeOption "Non-Overlake"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-natgw-storage",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("azuser")]
    [string]$AdminUsername = "azuser",
    
    [Parameter(Mandatory=$true)]
    [string]$AllowedRdpSourceAddress,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Yes", "No")]
    [string]$UseCustomImage = "No",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Enforce project VM username default
$AdminUsername = "azuser"

if ([string]::IsNullOrWhiteSpace($AdminPassword)) {
    $secureAdminPassword = Read-Host "Enter admin password for VM deployment" -AsSecureString
    $AdminPassword = [System.Net.NetworkCredential]::new('', $secureAdminPassword).Password
}

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
    
    # Check for module files
    $modules = @("clientvm/client.bicep", "simplestorage/storage.bicep")
    foreach ($module in $modules) {
        if (Test-Path $module) {
            Write-ColorOutput "✅ Module found: $module" "Green"
        } else {
            Write-ColorOutput "❌ Module missing: $module" "Red"
            $allGood = $false
        }
    }
    
    # Password validation
    if ($AdminPassword.Length -ge 12 -and $AdminPassword -cmatch '[A-Z]' -and $AdminPassword -cmatch '[a-z]' -and $AdminPassword -match '\d' -and $AdminPassword -match '[^A-Za-z0-9]') {
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
    } catch { return $AllowedRdpSourceAddress }
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and incur costs." "Yellow"
    Write-ColorOutput "⚠️  NAT Gateway: ~$45/month" "Yellow"
    Write-ColorOutput "⚠️  VM (B2s): ~$35/month" "Yellow"
    Write-ColorOutput "⚠️  Storage Account: ~$20/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Network: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Public IP: ~$4/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$110/month" "Yellow"
    
    $response = Read-Host "Do you want to continue with this modular deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "vm-natgw-storage-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($SubscriptionId) { az account set --subscription $SubscriptionId }
    
    if ($AllowedRdpSourceAddress -eq "*") {
        $publicIP = Get-PublicIP
        $AllowedRdpSourceAddress = $publicIP
        Write-ColorOutput "🌐 Auto-detected public IP: $AllowedRdpSourceAddress" "Cyan"
    }
    
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    
    if ($LASTEXITCODE -ne 0) { Write-ColorOutput "❌ Failed to create resource group" "Red"; exit 1 }
    
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", "main.bicep"
        "--name", $deploymentName
        "--parameters"
        "adminpassword=$AdminPassword"
        "adminusername=$AdminUsername"
        "allowedRdpSourceAddress=$AllowedRdpSourceAddress"
        "vmSizeOption=$VmSizeOption"
        "useCustomImage=$UseCustomImage"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis for modular deployment..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting modular deployment: $deploymentName" "Cyan"
        Write-ColorOutput "📄 Main template: main.bicep" "White"
        Write-ColorOutput "📦 Modules: VM client, storage account" "White"
        Write-ColorOutput "🏗️  Deploying VM with NAT Gateway and Storage..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 10-15 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Modular deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "🌐 VM with NAT Gateway and Storage deployed with:" "Green"
            Write-ColorOutput "   • Windows VM with outbound internet access" "White"
            Write-ColorOutput "   • NAT Gateway for secure outbound connectivity" "White"
            Write-ColorOutput "   • Storage Account for data persistence" "White"
            Write-ColorOutput "   • VNet with proper subnet configuration" "White"
        }
    } else { Write-ColorOutput "❌ Modular deployment failed" "Red"; exit 1 }
}

# Main script
Write-ColorOutput "🌐 VM with NAT Gateway and Storage (Modular) Deployment" "Cyan"
Write-ColorOutput "=======================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VM WITH NAT GATEWAY AND STORAGE (MODULAR)" "Cyan"
Write-ColorOutput "=============================================" "Cyan"
Write-ColorOutput "This modular deployment creates:" "White"
Write-ColorOutput "• Windows VM module (clientvm/client.bicep)" "White"
Write-ColorOutput "• Storage Account module (simplestorage/storage.bicep)" "White"
Write-ColorOutput "• NAT Gateway for outbound internet access" "White"
Write-ColorOutput "• VNet with subnet configuration" "White"
Write-ColorOutput "• Public IP and network security" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Custom Image: $UseCustomImage" "White"
Write-ColorOutput "• Allowed RDP Source: $AllowedRdpSourceAddress" "White"
Write-ColorOutput "• Deployment Type: Modular (main + 2 modules)" "White"
Write-ColorOutput "=============================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"