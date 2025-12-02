#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys Private Endpoint with Private Link Service and Internal Load Balancer

.DESCRIPTION
    This script deploys a Private Endpoint and Private Link Service setup with
    Internal Load Balancer and VMs for private connectivity demonstration.
    Azure Bastion is used for secure VM access without exposing any ports to the internet.

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

.PARAMETER UseCustomImage
    Use custom image from gallery (default: No)

.PARAMETER CustomImageResourceId
    Resource ID of custom image (optional)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -VmAdminUsername "azureuser" -VmAdminPassword "YourStrongPassword123!" -VmSizeOption "Non-Overlake"

.EXAMPLE
    .\deploy.ps1 -VmAdminUsername "azureuser" -VmAdminPassword "YourStrongPassword123!" -VmSizeOption "Overlake" -WhatIf
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

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  VMs (B2s): ~$30-40/month each" "Yellow"
    Write-ColorOutput "⚠️  Internal Load Balancer: ~$25/month" "Yellow"
    Write-ColorOutput "⚠️  Private Endpoints: ~$7/month" "Yellow"
    Write-ColorOutput "⚠️  Azure Bastion (Basic): ~$140/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Networks: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$215-230/month" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "pe-pls-vm-intlb-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
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
        "--output", "none"
        "--parameters"
        "vmAdminUsername=$VmAdminUsername"
        "vmAdminPassword=$VmAdminPassword"
        "vmSizeOption=$VmSizeOption"
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
            Show-DeploymentSummary
        }
    } else {
        Write-ColorOutput "❌ Deployment failed" "Red"; exit 1
    }
}

function Show-DeploymentSummary {
    Write-ColorOutput "" "White"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "📋 DEPLOYMENT SUMMARY & NEXT STEPS" "Cyan"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    
    # Get resource information
    Write-ColorOutput "" "White"
    Write-ColorOutput "🏗️  ARCHITECTURE OVERVIEW:" "Yellow"
    Write-ColorOutput "───────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  ┌─────────────────────────────────────────────────────────┐" "White"
    Write-ColorOutput "  │  SERVICE PROVIDER VNET (10.0.0.0/16)                    │" "White"
    Write-ColorOutput "  │  ┌─────────────────────────────────────────────────┐    │" "White"
    Write-ColorOutput "  │  │  Service VM (Backend) ──► Internal LB ──► PLS  │    │" "White"
    Write-ColorOutput "  │  │  [Runs IIS Web Server]                          │    │" "White"
    Write-ColorOutput "  │  └─────────────────────────────────────────────────┘    │" "White"
    Write-ColorOutput "  └──────────────────────────┬──────────────────────────────┘" "White"
    Write-ColorOutput "                             │ Private Link" "Green"
    Write-ColorOutput "  ┌──────────────────────────▼──────────────────────────────┐" "White"
    Write-ColorOutput "  │  CONSUMER VNET (10.0.0.0/24)                            │" "White"
    Write-ColorOutput "  │  ┌─────────────────────────────────────────────────┐    │" "White"
    Write-ColorOutput "  │  │  Consumer VM ──► Private Endpoint ──► PLS      │    │" "White"
    Write-ColorOutput "  │  │  [Test client to access service privately]      │    │" "White"
    Write-ColorOutput "  │  └─────────────────────────────────────────────────┘    │" "White"
    Write-ColorOutput "  │  ┌─────────────────────────────────────────────────┐    │" "White"
    Write-ColorOutput "  │  │  Azure Bastion [Secure browser-based VM access] │    │" "White"
    Write-ColorOutput "  │  └─────────────────────────────────────────────────┘    │" "White"
    Write-ColorOutput "  └─────────────────────────────────────────────────────────┘" "White"
    Write-ColorOutput "" "White"
    
    Write-ColorOutput "🖥️  DEPLOYED RESOURCES:" "Yellow"
    Write-ColorOutput "───────────────────────────────────────────────────────────────" "White"
    
    # Get VM names
    $vms = az vm list --resource-group $ResourceGroupName --query "[].{Name:name, PrivateIP:privateIps}" --output json 2>$null | ConvertFrom-Json
    $consumerVm = $vms | Where-Object { $_.Name -like "*Cnsmr*" }
    $serviceVm = $vms | Where-Object { $_.Name -like "*Svc*" }
    
    # Get Private Endpoint IP
    $peIp = az network private-endpoint show --resource-group $ResourceGroupName --name "myPrivateEndpoint" --query "customDnsConfigs[0].ipAddresses[0]" --output tsv 2>$null
    
    # Get Bastion name
    $bastionName = az network bastion list --resource-group $ResourceGroupName --query "[0].name" --output tsv 2>$null
    
    # Get ILB Frontend IP
    $ilbIp = az network lb show --resource-group $ResourceGroupName --name "myILB" --query "frontendIpConfigurations[0].privateIpAddress" --output tsv 2>$null
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "  📦 Consumer VM: $($consumerVm.Name)" "Cyan"
    Write-ColorOutput "     └─ Purpose: Test client VM to access the service via Private Endpoint" "White"
    Write-ColorOutput "     └─ Use this VM to test private connectivity to the backend service" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  📦 Service VM: $($serviceVm.Name)" "Cyan"
    Write-ColorOutput "     └─ Purpose: Backend server running IIS web service" "White"
    Write-ColorOutput "     └─ Sits behind Internal Load Balancer, exposed via Private Link Service" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  🔒 Azure Bastion: $bastionName" "Green"
    Write-ColorOutput "     └─ Purpose: Secure VM access without public IPs (browser-based RDP)" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  ⚖️  Internal Load Balancer IP: $ilbIp" "White"
    Write-ColorOutput "     └─ Purpose: Distributes traffic to backend Service VM(s)" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  🔗 Private Endpoint IP: $peIp" "Green"
    Write-ColorOutput "     └─ Purpose: Private IP in Consumer VNet that connects to the service" "White"
    Write-ColorOutput "     └─ This is the IP you use from Consumer VM to access the service!" "White"
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "🔐 HOW TO ACCESS VMs (via Azure Bastion)" "Yellow"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  Option 1: Azure Portal (Recommended)" "Green"
    Write-ColorOutput "  ─────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "  1. Go to: https://portal.azure.com" "White"
    Write-ColorOutput "  2. Navigate to: Resource Groups → $ResourceGroupName" "White"
    Write-ColorOutput "  3. Click on the VM you want to access" "White"
    Write-ColorOutput "  4. Click 'Connect' → 'Bastion'" "White"
    Write-ColorOutput "  5. Enter credentials:" "White"
    Write-ColorOutput "     • Username: $VmAdminUsername" "Cyan"
    Write-ColorOutput "     • Password: (the password you provided)" "Cyan"
    Write-ColorOutput "  6. Click 'Connect' - opens RDP session in browser!" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  Option 2: Azure CLI" "Green"
    Write-ColorOutput "  ─────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "  # Connect to Consumer VM:" "White"
    Write-ColorOutput "  az network bastion rdp --name $bastionName --resource-group $ResourceGroupName --target-resource-id `$(az vm show -g $ResourceGroupName -n $($consumerVm.Name) --query id -o tsv)" "Cyan"
    Write-ColorOutput "" "White"
    
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "🧪 HOW TO TEST THE DEPLOYMENT" "Yellow"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  Step 1: Connect to Consumer VM via Bastion (see above)" "Green"
    Write-ColorOutput "  ─────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "  → This simulates a client in a separate network accessing your service" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  Step 2: Test Private Endpoint Connectivity" "Green"
    Write-ColorOutput "  ─────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "  From the Consumer VM, open PowerShell and run:" "White"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  # Test connectivity to Private Endpoint (should succeed)" "Cyan"
    Write-ColorOutput "  Test-NetConnection -ComputerName $peIp -Port 80" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  # Or use curl to access the web server" "Cyan"
    Write-ColorOutput "  curl http://$peIp" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  Step 3: Verify IIS is Running on Service VM" "Green"
    Write-ColorOutput "  ─────────────────────────────────────────────────────────────" "White"
    Write-ColorOutput "  # From Consumer VM, test the Internal LB directly" "White"
    Write-ColorOutput "  curl http://$ilbIp" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "  ✅ Expected Result: You should see IIS default page HTML" "Green"
    Write-ColorOutput "" "White"
    
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "🔗 QUICK LINKS" "Yellow"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-ColorOutput "  • Resource Group: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName" "Cyan"
    Write-ColorOutput "  • Consumer VM:    https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$($consumerVm.Name)" "Cyan"
    Write-ColorOutput "" "White"
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" "Cyan"
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
Write-ColorOutput "• Azure Bastion for secure VM access (no public IPs)" "White"
Write-ColorOutput "• Virtual Networks with private connectivity" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Custom Image: $UseCustomImage" "White"
Write-ColorOutput "• VM Access: Azure Bastion (Secure)" "White"
Write-ColorOutput "===============================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"