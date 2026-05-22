#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Cross-Region VNet Peering Lab Bicep template

.DESCRIPTION
    Deploys two VNets in EastUS2 and WestUS2, creates bidirectional VNet peering,
    and deploys one Linux VM in each region using Overlake-capable VM size by default.
    Azure Bastion is deployed in both regions for secure management access.

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-crossregion-vnet-peering-lab)

.PARAMETER Location
    Azure region for the resource group metadata location (default: eastus2)

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd123!"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-crossregion-vnet-peering-lab",

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminPasswordOrKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet('password', 'sshPublicKey')]
    [string]$AuthenticationType = 'password',

    [Parameter(Mandatory = $false)]
    [string]$EastRegion = 'eastus2',

    [Parameter(Mandatory = $false)]
    [string]$WestRegion = 'westus2',

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-AzureCLI {
    Write-ColorOutput "🔍 Checking Azure CLI..." "Cyan"
    az version --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Azure CLI is not installed or not available in PATH." "Red"
        return $false
    }
    Write-ColorOutput "✅ Azure CLI is available." "Green"
    return $true
}

function Test-AzureLogin {
    Write-ColorOutput "🔍 Checking Azure login state..." "Cyan"
    az account show --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ You are not logged in to Azure. Run: az login" "Red"
        return $false
    }
    Write-ColorOutput "✅ Azure login is active." "Green"
    return $true
}

function Test-BicepCLI {
    Write-ColorOutput "🔍 Checking Bicep CLI..." "Cyan"
    az bicep version --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "⚠️  Bicep CLI not found. Installing via Azure CLI..." "Yellow"
        az bicep install --output none
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Failed to install Bicep CLI." "Red"
            return $false
        }
    }
    Write-ColorOutput "✅ Bicep CLI is available." "Green"
    return $true
}

function Test-PasswordComplexity {
    param([string]$Password)

    if ($Password.Length -lt 12) { return $false }
    if ($Password -notmatch '[A-Z]') { return $false }
    if ($Password -notmatch '[a-z]') { return $false }
    if ($Password -notmatch '\d') { return $false }
    if ($Password -notmatch '[^a-zA-Z0-9]') { return $false }
    return $true
}

function Test-SSHKeyFormat {
    param([string]$PublicKey)

    $sshKeyPattern = '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\s+[A-Za-z0-9+/=]+(\s+.+)?$'
    return ($PublicKey -match $sshKeyPattern)
}

function Test-Prerequisites {
    if (-not (Test-AzureCLI)) { return $false }
    if (-not (Test-AzureLogin)) { return $false }
    if (-not (Test-BicepCLI)) { return $false }

    if ($AuthenticationType -eq 'password') {
        Write-ColorOutput "🔍 Validating password complexity..." "Cyan"
        if (-not (Test-PasswordComplexity -Password $AdminPasswordOrKey)) {
            Write-ColorOutput "❌ Password must be 12+ chars and include upper/lowercase, number, and special character." "Red"
            return $false
        }
        Write-ColorOutput "✅ Password complexity validation passed." "Green"
    }

    if ($AuthenticationType -eq 'sshPublicKey') {
        Write-ColorOutput "🔍 Validating SSH public key format..." "Cyan"
        if (-not (Test-SSHKeyFormat -PublicKey $AdminPasswordOrKey)) {
            Write-ColorOutput "❌ SSH public key format appears invalid." "Red"
            return $false
        }
        Write-ColorOutput "✅ SSH public key format validation passed." "Green"
    }

    return $true
}

function Get-UserConfirmation {
    if ($Force) { return $true }

    Write-ColorOutput "" "White"
    Write-ColorOutput "⚠️  Estimated monthly cost (rough):" "Yellow"
    Write-ColorOutput "   • 2x Linux VMs (D2s_v5): ~`$120-`$180" "Yellow"
    Write-ColorOutput "   • 2x Azure Bastion Basic: ~`$280" "Yellow"
    Write-ColorOutput "   • Networking + data transfer: variable" "Yellow"
    Write-ColorOutput "   • Total estimate: ~`$420-`$520/month" "Yellow"
    Write-ColorOutput "" "White"

    $choice = Read-Host "Proceed with deployment? (y/N)"
    if ($choice -notin @('y', 'Y', 'yes', 'YES')) {
        Write-ColorOutput "Deployment canceled by user." "Yellow"
        return $false
    }

    return $true
}

function Start-Deployment {
    Write-ColorOutput "🎯 Target resource group: $ResourceGroupName" "Cyan"
    Write-ColorOutput "🎯 Deployment regions: East=$EastRegion, West=$WestRegion" "Cyan"

    Write-ColorOutput "📦 Creating resource group..." "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create or access resource group '$ResourceGroupName'." "Red"
        return $false
    }

    $deploymentName = "crossregion-peering-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $deploymentArgs = @(
        'deployment', 'group', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $deploymentName,
        '--template-file', 'main.bicep',
        '--parameters', "adminUsername=$AdminUsername",
        '--parameters', "adminPasswordOrKey=$AdminPasswordOrKey",
        '--parameters', "authenticationType=$AuthenticationType",
        '--parameters', "eastRegion=$EastRegion",
        '--parameters', "westRegion=$WestRegion"
    )

    if ($WhatIf) {
        Write-ColorOutput "🚀 Running WHAT-IF deployment..." "Cyan"
        $deploymentArgs[2] = 'what-if'
    }
    else {
        Write-ColorOutput "🚀 Starting deployment..." "Cyan"
    }

    az @deploymentArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Deployment failed." "Red"
        return $false
    }

    if ($WhatIf) {
        Write-ColorOutput "✅ What-if completed successfully." "Green"
        return $true
    }

    $eastVmIp = az vm show -d --resource-group $ResourceGroupName --name "crpeer-vm-east" --query privateIps -o tsv 2>$null
    $westVmIp = az vm show -d --resource-group $ResourceGroupName --name "crpeer-vm-west" --query privateIps -o tsv 2>$null

    Write-ColorOutput "🎉 Deployment completed successfully!" "Green"
    Write-ColorOutput "" "White"
    Write-ColorOutput "Cross-region VM connectivity lab is ready:" "White"
    Write-ColorOutput "• East VM: crpeer-vm-east ($eastVmIp) in $EastRegion" "White"
    Write-ColorOutput "• West VM: crpeer-vm-west ($westVmIp) in $WestRegion" "White"
    Write-ColorOutput "• VNet peering configured bidirectionally" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "Suggested verification steps:" "Cyan"
    Write-ColorOutput "1) Connect to crpeer-vm-east using Azure Bastion in portal" "White"
    Write-ColorOutput "2) Run: ping -c 4 $westVmIp" "White"
    Write-ColorOutput "3) Connect to crpeer-vm-west and run: ping -c 4 $eastVmIp" "White"

    return $true
}

Write-ColorOutput "=== Cross-Region VNet Peering Lab Deployment ===" "Cyan"

if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisite checks failed." "Red"
    exit 1
}

if (-not (Get-UserConfirmation)) {
    exit 0
}

if (-not (Start-Deployment)) {
    exit 1
}

exit 0
