#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Private Endpoint Policies Lab with modular architecture

.DESCRIPTION
    This script deploys a comprehensive Private Endpoint policies lab with
    client VM, firewall, SQL server, VNet peerings, and route tables using modular Bicep templates.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-pe-policies-lab)

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER AdminPassword
    Administrator password for the VMs and SQL server

.PARAMETER AdminUsername
    Administrator username for the VMs and SQL server

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
    .\deploy.ps1 -AdminPassword "YourStrongPassword123!" -AdminUsername "azureuser" -AllowedRdpSourceAddress "203.0.113.0/24" -VmSizeOption "Non-Overlake"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-policies-lab",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
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
    $modules = @("clientVM/client.bicep", "firewall/firewall.bicep", "pesqlserver/sqlserver.bicep")
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
    
    Write-ColorOutput "⚠️  This deployment will create multiple Azure resources and may incur significant costs." "Yellow"
    Write-ColorOutput "⚠️  Azure Firewall Standard: ~$1.25/hour (~$912/month)" "Yellow"
    Write-ColorOutput "⚠️  Azure SQL Database: ~$150-300/month" "Yellow"
    Write-ColorOutput "⚠️  VMs (B2s): ~$30-40/month each" "Yellow"
    Write-ColorOutput "⚠️  Private Endpoints: ~$7/month each" "Yellow"
    Write-ColorOutput "⚠️  Virtual Networks: ~$10/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$1200+/month" "Yellow"
    
    $response = Read-Host "Do you want to continue with this high-cost modular deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "pe-policies-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
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
        Write-ColorOutput "📦 Modules: client VM, firewall, SQL server" "White"
        Write-ColorOutput "🏗️  Deploying comprehensive Private Endpoint policies lab..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 45-60 minutes (complex modular deployment)" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Modular deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "🔐 Private Endpoint Policies Lab deployed with:" "Green"
            Write-ColorOutput "   • Client VM for testing" "White"
            Write-ColorOutput "   • Azure Firewall for network security" "White"
            Write-ColorOutput "   • SQL Server with private endpoint" "White"
            Write-ColorOutput "   • VNet peering and route tables" "White"
        }
    } else { Write-ColorOutput "❌ Modular deployment failed" "Red"; exit 1 }
}

# Main script
Write-ColorOutput "🔐 Private Endpoint Policies Lab (Modular) Deployment" "Cyan"
Write-ColorOutput "====================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  PRIVATE ENDPOINT POLICIES LAB (MODULAR)" "Cyan"
Write-ColorOutput "=============================================" "Cyan"
Write-ColorOutput "This modular deployment creates:" "White"
Write-ColorOutput "• Client VM module (clientVM/client.bicep)" "White"
Write-ColorOutput "• Firewall module (firewall/firewall.bicep)" "White"
Write-ColorOutput "• SQL Server module (pesqlserver/sqlserver.bicep)" "White"
Write-ColorOutput "• VNet peering and route tables" "White"
Write-ColorOutput "• Private endpoint policies configuration" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Custom Image: $UseCustomImage" "White"
Write-ColorOutput "• Allowed RDP Source: $AllowedRdpSourceAddress" "White"
Write-ColorOutput "• Deployment Type: Modular (main + 3 modules)" "White"
Write-ColorOutput "=============================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"