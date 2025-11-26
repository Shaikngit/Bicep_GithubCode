#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Simple Internal Load Balancer Bicep template

.DESCRIPTION
    This script deploys a simple internal load balancer with backend VMs, Bastion, and supporting network infrastructure.
    The deployment includes proper validation, error handling, and detailed logging.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-simple-int-lb)

.PARAMETER Location
    Azure region for deployment (default: southeastasia)

.PARAMETER AdminUsername
    Administrator username for the VMs

.PARAMETER AdminPassword
    Administrator password for the VMs (must meet Azure complexity requirements)

.PARAMETER VmNamePrefix
    Prefix to use for VM names (default: BackendVM)

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake (default: Non-Overlake)

.PARAMETER VNetAddressPrefix
    Virtual network address prefix (default: 10.0.0.0/16)

.PARAMETER VNetSubnetAddressPrefix
    Backend subnet address prefix (default: 10.0.0.0/24)

.PARAMETER VNetBastionSubnetAddressPrefix
    Bastion subnet address prefix (default: 10.0.2.0/24)

.PARAMETER LbPublicIPAddress
    Load balancer internal IP address (default: 10.0.0.6)

.PARAMETER UseCustomImage
    Specifies whether to use a custom image (Yes/No, default: No)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current subscription if not specified)

.PARAMETER WhatIf
    Preview deployment without making changes

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourStrongPassword123!" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-simple-int-lb",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$VmNamePrefix = "BackendVM",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption = "Non-Overlake",
    
    [Parameter(Mandatory=$false)]
    [string]$VNetAddressPrefix = "10.0.0.0/16",
    
    [Parameter(Mandatory=$false)]
    [string]$VNetSubnetAddressPrefix = "10.0.0.0/24",
    
    [Parameter(Mandatory=$false)]
    [string]$VNetBastionSubnetAddressPrefix = "10.0.2.0/24",
    
    [Parameter(Mandatory=$false)]
    [string]$LbPublicIPAddress = "10.0.0.6",
    
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
        Write-ColorOutput "✅ Azure Bicep version: $version" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Bicep CLI not found. Installing..." "Yellow"
        az bicep install
        return $true
    }
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

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    
    $azCliOk = Test-AzureCLI
    $azLoginOk = Test-AzureLogin
    $bicepOk = Test-BicepCLI
    $passwordOk = Test-PasswordComplexity -Password $AdminPassword
    
    return ($azCliOk -and $azLoginOk -and $bicepOk -and $passwordOk)
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  Internal Load Balancer: ~$20/month" "Yellow"
    Write-ColorOutput "⚠️  Backend VMs (2x B2s): ~$60-80/month" "Yellow"
    Write-ColorOutput "⚠️  Azure Bastion: ~$140/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$220-240/month" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

function Start-Deployment {
    $deploymentName = "simple-int-lb-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
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
        "adminPassword=$AdminPassword"
        "vmNamePrefix=$VmNamePrefix"
        "vmSizeOption=$VmSizeOption"
        "vNetAddressPrefix=$VNetAddressPrefix"
        "vNetSubnetAddressPrefix=$VNetSubnetAddressPrefix"
        "vNetBastionSubnetAddressPrefix=$VNetBastionSubnetAddressPrefix"
        "lbPublicIPAddress=$LbPublicIPAddress"
        "useCustomImage=$UseCustomImage"
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
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
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

Write-ColorOutput "🔥 Simple Internal Load Balancer Deployment Script" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  SIMPLE INTERNAL LOAD BALANCER DEPLOYMENT" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "This script will deploy:" "White"
Write-ColorOutput "• Internal Load Balancer (Standard SKU)" "White"
Write-ColorOutput "• 2 Backend Windows VMs" "White"
Write-ColorOutput "• Virtual Network with multiple subnets" "White"
Write-ColorOutput "• Azure Bastion for secure access" "White"
Write-ColorOutput "• Network Security Groups" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• LB Internal IP: $LbPublicIPAddress" "White"
if ($WhatIf) {
    Write-ColorOutput "• Deployment Type: What-If Analysis" "Yellow"
} else {
    Write-ColorOutput "• Deployment Type: Full Deployment" "White"
    Write-ColorOutput "• Estimated Duration: 10-15 minutes" "White"
}
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "" "White"

# Get user confirmation
if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"
    exit 1
}

# Start deployment
Start-Deployment

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Script execution completed!" "Green"