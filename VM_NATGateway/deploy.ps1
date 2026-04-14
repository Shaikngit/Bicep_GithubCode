#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys VM_NATGateway Bicep template

.DESCRIPTION
    This script deploys a Linux VM behind a NAT Gateway for outbound internet access.
    The deployment includes a VNet, NSG, NAT Gateway with a public IP, and a Linux VM
    with no public IP of its own — all outbound traffic routes through the NAT Gateway.

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-vm-natgateway)

.PARAMETER Location
    Azure region (default: southeastasia)

.PARAMETER AdminUsername
    Administrator username for the VM

.PARAMETER AdminPasswordOrKey
    Administrator password or SSH public key for the VM

.PARAMETER AuthenticationType
    Type of authentication to use (sshPublicKey or password, default: password)

.PARAMETER UbuntuOSVersion
    Ubuntu OS version (Ubuntu-2004 or Ubuntu-2204, default: Ubuntu-2204)

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake (default: Non-Overlake)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current subscription if not specified)

.PARAMETER WhatIf
    Preview deployment without making changes

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "YourStrongPassword123!"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "ssh-rsa AAAA..." -AuthenticationType "sshPublicKey"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "YourStrongPassword123!" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-natgateway",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,

    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,

    [Parameter(Mandatory=$false)]
    [ValidateSet("sshPublicKey", "password")]
    [string]$AuthenticationType = "password",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Ubuntu-2004", "Ubuntu-2204")]
    [string]$UbuntuOSVersion = "Ubuntu-2204",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption = "Non-Overlake",

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
        Write-ColorOutput "✅ Current subscription: $($account.name) ($($account.id))" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'." "Red"
        return $false
    }
}

function Test-BicepCLI {
    try {
        $version = az bicep version
        Write-ColorOutput "✅ Bicep CLI version: $version" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Bicep CLI not found. Installing..." "Yellow"
        az bicep install
        return $true
    }
}

function Test-Credentials {
    if ($AuthenticationType -eq "password") {
        return Test-PasswordComplexity -Password $AdminPasswordOrKey
    } elseif ($AuthenticationType -eq "sshPublicKey") {
        return Test-SSHKeyFormat -SSHKey $AdminPasswordOrKey
    }
    return $false
}

function Test-PasswordComplexity {
    param([string]$Password)

    $hasUpper = $Password -cmatch '[A-Z]'
    $hasLower = $Password -cmatch '[a-z]'
    $hasDigit = $Password -match '\d'
    $hasSpecial = $Password -match '[^A-Za-z0-9]'
    $hasLength = $Password.Length -ge 12

    if ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $hasLength) {
        Write-ColorOutput "✅ Password meets complexity requirements." "Green"
        return $true
    } else {
        Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character." "Red"
        return $false
    }
}

function Test-SSHKeyFormat {
    param([string]$SSHKey)

    if ($SSHKey -match '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+/]+=*') {
        Write-ColorOutput "✅ SSH key format is valid." "Green"
        return $true
    } else {
        Write-ColorOutput "❌ SSH key format is invalid. Should start with ssh-rsa, ssh-ed25519, etc." "Red"
        return $false
    }
}

function Test-Prerequisites {
    Write-ColorOutput "`n🔍 Checking prerequisites..." "Cyan"

    $azCliOk = Test-AzureCLI
    $azLoginOk = Test-AzureLogin
    $bicepOk = Test-BicepCLI
    $credentialsOk = Test-Credentials

    if ($azCliOk -and $azLoginOk -and $bicepOk -and $credentialsOk) {
        Write-ColorOutput "🎉 All prerequisites passed!`n" "Green"
        return $true
    }
    return $false
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }

    Write-ColorOutput "`n⚠️  Estimated monthly cost: ~$35-45/month" "Yellow"
    Write-ColorOutput "⚠️  Linux VM (D2s_v4): ~$30/month" "Yellow"
    Write-ColorOutput "⚠️  NAT Gateway: ~$4.50/month + data processing" "Yellow"
    Write-ColorOutput "⚠️  Public IP (Standard): ~$3.60/month" "Yellow"
    Write-ColorOutput "📦 Resource Group: $ResourceGroupName" "Cyan"
    Write-ColorOutput "🎯 Region: $Location" "Cyan"

    $response = Read-Host "`nProceed with deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

function Start-Deployment {
    $deploymentName = "vm-natgateway-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $templateFile = "main.bicep"

    # Set subscription if provided
    if ($SubscriptionId) {
        Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
        az account set --subscription $SubscriptionId
    }

    # Create resource group
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"
        exit 1
    }

    # Build deployment command
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", $templateFile
        "--name", $deploymentName
        "--parameters"
        "adminUsername=$AdminUsername"
        "adminPasswordOrKey=$AdminPasswordOrKey"
        "authenticationType=$AuthenticationType"
        "ubuntuOSVersion=$UbuntuOSVersion"
        "vmSizeOption=$VmSizeOption"
    )

    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "📄 Template: $templateFile" "White"
        Write-ColorOutput "📍 Target: Resource Group '$ResourceGroupName'" "White"
        Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
        Write-ColorOutput "🏗️  Deploying resources..." "Cyan"
    }

    # Execute deployment
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]

    if ($LASTEXITCODE -eq 0) {
        if ($WhatIf) {
            Write-ColorOutput "✅ What-if analysis completed successfully!" "Green"
        } else {
            Write-ColorOutput "✅ Deployment completed successfully!" "Green"
            Write-ColorOutput "⏰ End time: $(Get-Date)" "White"

            # Get deployment outputs
            Write-ColorOutput "`n📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table
        }
    } else {
        Write-ColorOutput "❌ Deployment failed with exit code: $LASTEXITCODE" "Red"
        Write-ColorOutput "💡 Check the Azure portal for detailed error information." "Yellow"
        Write-ColorOutput "💡 Deployment name: $deploymentName" "Yellow"
        exit 1
    }
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔥 VM behind NAT Gateway Deployment Script" "Cyan"
Write-ColorOutput "============================================" "Cyan"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VM + NAT GATEWAY DEPLOYMENT" "Cyan"
Write-ColorOutput "================================" "Cyan"
Write-ColorOutput "This script will deploy:" "White"
Write-ColorOutput "• Linux Ubuntu VM (no public IP)" "White"
Write-ColorOutput "• NAT Gateway with Standard public IP" "White"
Write-ColorOutput "• Virtual Network with NAT Gateway subnet" "White"
Write-ColorOutput "• Network Security Group with SSH rule" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• Ubuntu Version: $UbuntuOSVersion" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Authentication: $AuthenticationType" "White"
if ($WhatIf) {
    Write-ColorOutput "• Deployment Type: What-If Analysis" "Yellow"
} else {
    Write-ColorOutput "• Deployment Type: Full Deployment" "White"
    Write-ColorOutput "• Estimated Duration: 5-10 minutes" "White"
}
Write-ColorOutput "================================" "Cyan"
Write-ColorOutput "" "White"

# Get user confirmation
if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"
    exit 0
}

# Start deployment
Start-Deployment

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Script execution completed!" "Green"
Write-ColorOutput "" "White"
Write-ColorOutput "💡 Note: The VM has no public IP. To SSH into the VM, use Azure Bastion" "Yellow"
Write-ColorOutput "   or deploy a jump box in the same VNet. Outbound traffic uses the NAT Gateway." "Yellow"
