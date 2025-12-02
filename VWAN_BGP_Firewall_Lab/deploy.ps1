# ============================================================================
# VWAN BGP over IPsec with Azure Firewall Lab - Deployment Script (Azure CLI)
# ============================================================================
# This script deploys the Virtual WAN topology with:
# - Virtual WAN + Virtual Hub (Southeast Asia)
# - Hub VPN Gateway and Azure Firewall
# - Two Spoke VNets connected to the hub
# - Simulated On-Prem VNet with VPN Gateway (East Asia)
# - BGP over IPsec VPN connection
# - Azure Bastion and Test VMs
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-vwan-bgp-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentPrefix = "vwan-bgp",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUsername = "azureadmin",
    
    [Parameter(Mandatory = $true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory = $true)]
    [string]$VpnSharedKey
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VWAN BGP Lab Deployment (Azure CLI)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if logged in to Azure CLI
Write-Host "`nChecking Azure CLI login status..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in to Azure CLI. Please login..." -ForegroundColor Yellow
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "Subscription: $($account.name)" -ForegroundColor Green

# Create Resource Group
Write-Host "`nCreating Resource Group: $ResourceGroupName in $Location..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "Resource Group created successfully!" -ForegroundColor Green

# Deploy the Bicep template
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Starting Bicep deployment..." -ForegroundColor Cyan
Write-Host "This deployment will take approximately 45-60 minutes" -ForegroundColor Yellow
Write-Host "due to VPN Gateway provisioning times." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan

$templateFile = Join-Path $PSScriptRoot "main.bicep"
$deploymentName = "vwan-bgp-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "`nDeploying template: $templateFile" -ForegroundColor Yellow
Write-Host "Deployment name: $deploymentName" -ForegroundColor Yellow

$startTime = Get-Date

try {
    $result = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters deploymentPrefix=$DeploymentPrefix `
        --parameters adminUsername=$AdminUsername `
        --parameters adminPassword=$AdminPassword `
        --parameters vpnSharedKey=$VpnSharedKey `
        --output json | ConvertFrom-Json

    $endTime = Get-Date
    $duration = $endTime - $startTime

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed with exit code $LASTEXITCODE"
    }

    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green

    # Display outputs
    Write-Host "`n=== Deployment Outputs ===" -ForegroundColor Cyan
    
    $outputs = $result.properties.outputs

    Write-Host "`n--- Virtual WAN ---" -ForegroundColor Yellow
    Write-Host "vWAN Name: $($outputs.virtualWanName.value)"
    Write-Host "vWAN ID: $($outputs.virtualWanId.value)"
    
    Write-Host "`n--- Virtual Hub ---" -ForegroundColor Yellow
    Write-Host "vHub Name: $($outputs.virtualHubName.value)"
    Write-Host "vHub Address Prefix: $($outputs.virtualHubAddressPrefix.value)"
    
    Write-Host "`n--- Hub VPN Gateway ---" -ForegroundColor Yellow
    Write-Host "VPN Gateway Name: $($outputs.hubVpnGatewayName.value)"
    
    Write-Host "`n--- Azure Firewall ---" -ForegroundColor Yellow
    Write-Host "Firewall Name: $($outputs.azureFirewallName.value)"
    Write-Host "Firewall Private IP: $($outputs.azureFirewallPrivateIp.value)"
    
    Write-Host "`n--- Spoke VNets ---" -ForegroundColor Yellow
    Write-Host "Spoke 1: $($outputs.vnetSpoke1Name.value)"
    Write-Host "Spoke 2: $($outputs.vnetSpoke2Name.value)"
    
    Write-Host "`n--- On-Prem Resources ---" -ForegroundColor Yellow
    Write-Host "On-Prem VNet: $($outputs.vnetOnPremName.value)"
    Write-Host "On-Prem VPN Gateway: $($outputs.onPremVpnGatewayName.value)"
    Write-Host "On-Prem VPN Gateway Public IP: $($outputs.onPremVpnGatewayPublicIp.value)"
    
    Write-Host "`n--- VPN Site & Connection ---" -ForegroundColor Yellow
    Write-Host "VPN Site: $($outputs.vpnSiteName.value)"
    Write-Host "VPN Connection: $($outputs.vpnConnectionName.value)"
    
    Write-Host "`n--- Test VMs ---" -ForegroundColor Yellow
    Write-Host "Spoke 1 VM IP: $($outputs.vmSpoke1PrivateIp.value)"
    Write-Host "Spoke 2 VM IP: $($outputs.vmSpoke2PrivateIp.value)"
    Write-Host "On-Prem VM IP: $($outputs.vmOnPremPrivateIp.value)"
    
    Write-Host "`n--- Azure Bastion ---" -ForegroundColor Yellow
    Write-Host "Bastion (Spoke 1): $($outputs.bastionSpoke1Name.value)"
    Write-Host "Bastion (On-Prem): $($outputs.bastionOnPremName.value)"

    # Save outputs to file
    $outputFile = Join-Path $PSScriptRoot "deployment-outputs.json"
    $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "`nOutputs saved to: $outputFile" -ForegroundColor Green

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "NEXT STEPS - Testing Connectivity" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host @"

1. Wait for VPN connection to establish (check in Azure Portal)
   - Navigate to Virtual WAN > Hub > VPN (Site to site)
   - Connection status should show 'Connected'

2. Check BGP status:
   - In Azure Portal, go to the Hub VPN Gateway
   - Check BGP peer status
   
3. Connect to VMs via Bastion:
   - Use Bastion in Spoke 1 to connect to Spoke VMs
   - Use Bastion in On-Prem VNet to connect to On-Prem VM

4. Test connectivity from On-Prem VM:
   ping $($outputs.vmSpoke1PrivateIp.value)
   ping $($outputs.vmSpoke2PrivateIp.value)

5. Test connectivity from Spoke 1 VM:
   ping $($outputs.vmOnPremPrivateIp.value)
   ping $($outputs.vmSpoke2PrivateIp.value)

See README.md for detailed testing instructions.
"@

} catch {
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "`n============================================" -ForegroundColor Red
    Write-Host "Deployment failed!" -ForegroundColor Red
    Write-Host "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Get deployment error details
    Write-Host "`nGetting deployment error details..." -ForegroundColor Yellow
    az deployment group show --name $deploymentName --resource-group $ResourceGroupName --query "properties.error" --output json
    
    throw
}
