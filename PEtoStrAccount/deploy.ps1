#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Private Endpoint to Storage Account with custom scripts

.DESCRIPTION
    This script deploys a Private Endpoint to Azure Storage Account (ADLS Gen2)
    with virtual machines, Log Analytics workspace, and custom script execution.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-pe-storage-account)

.PARAMETER Location
    Azure region for deployment (default: eastus)

.PARAMETER AdminPasswordOrKey
    Administrator password or SSH public key for VM

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake

.PARAMETER ScriptFileUri
    URI to the custom script file to execute on VM

.PARAMETER WorkspaceName
    Name for the Log Analytics workspace

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -AdminPasswordOrKey "YourStrongPassword123!" -VmSizeOption "Non-Overlake" -ScriptFileUri "https://raw.githubusercontent.com/example/script.sh" -WorkspaceName "myworkspace"

.EXAMPLE
    .\deploy.ps1 -AdminPasswordOrKey "YourStrongPassword123!" -VmSizeOption "Overlake" -ScriptFileUri "https://example.com/script.sh" -WorkspaceName "testws" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-storage-account",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$true)]
    [string]$ScriptFileUri,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
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
    
    # Validate workspace name (alphanumeric and hyphens only, 4-63 chars)
    if ($WorkspaceName -notmatch '^[a-zA-Z0-9-]{4,63}$') {
        Write-ColorOutput "❌ Workspace name must be 4-63 characters, alphanumeric and hyphens only" "Red"
        $allGood = $false
    } else {
        Write-ColorOutput "✅ Workspace name format valid" "Green"
    }
    
    return $allGood
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  ADLS Gen2 Storage Account: ~$25-50/month (depending on usage)" "Yellow"
    Write-ColorOutput "⚠️  VM (B2s): ~$30-40/month" "Yellow"
    Write-ColorOutput "⚠️  Log Analytics Workspace: ~$10-30/month" "Yellow"
    Write-ColorOutput "⚠️  Private Endpoints: ~$7/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Network: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$80-135/month" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "pe-storage-account-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
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
        "adminPasswordOrKey=$AdminPasswordOrKey"
        "vmSizeOption=$VmSizeOption"
        "scriptFileUri=$ScriptFileUri"
        "workspaceName=$WorkspaceName"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "🏗️  Deploying Private Endpoint to Storage Account..." "Cyan"
        Write-ColorOutput "⏱️  Estimated duration: 15-25 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            Write-ColorOutput "📊 Deployment outputs:" "Cyan"
            az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output table 2>/dev/null
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "🔗 Private Endpoint to Storage Account deployed successfully!" "Green"
            Write-ColorOutput "💡 Check the storage account private connectivity in the Azure portal" "Cyan"
        }
    } else {
        Write-ColorOutput "❌ Deployment failed" "Red"; exit 1
    }
}

# Main script
Write-ColorOutput "🗄️  Private Endpoint to Storage Account Deployment" "Cyan"
Write-ColorOutput "==================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  PRIVATE ENDPOINT TO STORAGE ACCOUNT LAB" "Cyan"
Write-ColorOutput "===========================================" "Cyan"
Write-ColorOutput "• ADLS Gen2 Storage Account with private connectivity" "White"
Write-ColorOutput "• Private Endpoint for secure access" "White"
Write-ColorOutput "• VM with custom script execution" "White"
Write-ColorOutput "• Log Analytics workspace for monitoring" "White"
Write-ColorOutput "• Virtual Network with private DNS zones" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Workspace Name: $WorkspaceName" "White"
Write-ColorOutput "• Script URI: $ScriptFileUri" "White"
Write-ColorOutput "===========================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"