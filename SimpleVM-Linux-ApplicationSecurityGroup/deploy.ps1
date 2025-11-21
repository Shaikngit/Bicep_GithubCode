#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Linux VM with Application Security Group and NGINX

.DESCRIPTION
    This script deploys a Linux VM with Application Security Group configuration
    and installs NGINX web server using custom script extension.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-linux-vm-asg)

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER AdminUsername
    Administrator username for the VM

.PARAMETER AdminPasswordOrKey
    Administrator password or SSH public key

.PARAMETER ScriptFileUri
    URI to the NGINX installation script

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake

.PARAMETER AuthenticationType
    Authentication type: password or sshPublicKey (default: password)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "YourStrongPassword123!" -ScriptFileUri "https://raw.githubusercontent.com/example/install_nginx.sh" -VmSizeOption "Non-Overlake"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "ssh-rsa AAAA..." -ScriptFileUri "https://example.com/nginx.sh" -VmSizeOption "Overlake" -AuthenticationType "sshPublicKey" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-linux-vm-asg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,
    
    [Parameter(Mandatory=$true)]
    [string]$ScriptFileUri,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("password", "sshPublicKey")]
    [string]$AuthenticationType = "password",
    
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
    
    # Validate script URI
    if ($ScriptFileUri -and -not ($ScriptFileUri -match '^https?://')) {
        Write-ColorOutput "❌ Script file URI must be a valid HTTP/HTTPS URL" "Red"
        $allGood = $false
    } else {
        Write-ColorOutput "✅ Script URI format valid" "Green"
    }
    
    # Authentication validation
    if ($AuthenticationType -eq "password") {
        $hasUpper = $AdminPasswordOrKey -cmatch '[A-Z]'
        $hasLower = $AdminPasswordOrKey -cmatch '[a-z]'
        $hasDigit = $AdminPasswordOrKey -match '\d'
        $hasSpecial = $AdminPasswordOrKey -match '[^A-Za-z0-9]'
        $hasLength = $AdminPasswordOrKey.Length -ge 12
        
        if ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $hasLength) {
            Write-ColorOutput "✅ Password meets complexity requirements" "Green"
        } else {
            Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character" "Red"
            $allGood = $false
        }
    } else {
        Write-ColorOutput "✅ SSH public key authentication selected" "Green"
    }
    
    return $allGood
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  Linux VM (B2s): ~$30-40/month" "Yellow"
    Write-ColorOutput "⚠️  Public IP: ~$4/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Network: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Application Security Group: No additional cost" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$40-50/month" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "linux-vm-asg-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($SubscriptionId) { az account set --subscription $SubscriptionId }
    
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"; exit 1
    }
    
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", "azuredeploy.bicep"
        "--name", $deploymentName
        "--parameters"
        "adminUsername=$AdminUsername"
        "adminPasswordOrKey=$AdminPasswordOrKey"
        "scriptFileUri=$ScriptFileUri"
        "vmSizeOption=$VmSizeOption"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "🏗️  Deploying Linux VM with Application Security Group..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 10-15 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "🐧 Linux VM with Application Security Group deployed!" "Green"
            Write-ColorOutput "🌐 NGINX web server installation initiated via custom script" "Cyan"
            Write-ColorOutput "💡 Access the web server via the public IP once deployment completes" "Yellow"
        }
    } else {
        Write-ColorOutput "❌ Deployment failed" "Red"; exit 1
    }
}

# Main script
Write-ColorOutput "🐧 Linux VM + Application Security Group Deployment" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  LINUX VM + APPLICATION SECURITY GROUP LAB" "Cyan"
Write-ColorOutput "===============================================" "Cyan"
Write-ColorOutput "• Ubuntu Linux VM" "White"
Write-ColorOutput "• Application Security Group configuration" "White"
Write-ColorOutput "• NGINX web server installation" "White"
Write-ColorOutput "• Network Security Group with proper rules" "White"
Write-ColorOutput "• Virtual Network and public IP" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Authentication: $AuthenticationType" "White"
Write-ColorOutput "• Script URI: $ScriptFileUri" "White"
Write-ColorOutput "===============================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"