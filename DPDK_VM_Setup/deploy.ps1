# Set variables
$resourceGroupName = "dpdk-lab-rg"
$location = "southeastasia"
$templateFile = "$PSScriptRoot\main.bicep"

# Prompt for credentials
$adminUsername = Read-Host -Prompt "Enter admin username"
$adminPassword = Read-Host -Prompt "Enter admin password" -AsSecureString

# Create resource group
Write-Host "Creating resource group '$resourceGroupName' in '$location'..." -ForegroundColor Cyan
az group create --name $resourceGroupName --location $location

# Deploy the Bicep template
Write-Host "Deploying DPDK VM infrastructure..." -ForegroundColor Cyan
Write-Host "This will create:" -ForegroundColor Yellow
Write-Host "  - 2x Standard_D8s_v6 VMs with MANA Hardware (Microsoft Azure Network Adapter)" -ForegroundColor Yellow
Write-Host "  - Dual NICs per VM (management + DPDK)" -ForegroundColor Yellow
Write-Host "  - VNet with DPDK subnet" -ForegroundColor Yellow
Write-Host "  - Public IPs for SSH access" -ForegroundColor Yellow
Write-Host ""

$deployment = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file $templateFile `
    --parameters adminUsername=$adminUsername adminPassword=$adminPassword hardwareType='MANA' `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "VM Details:" -ForegroundColor Cyan
    Write-Host "  VM1 Name: $($deployment.properties.outputs.vm1Name.value)" -ForegroundColor White
    Write-Host "  VM1 Private IP: $($deployment.properties.outputs.vm1PrivateIP.value)" -ForegroundColor White
    Write-Host "  VM2 Name: $($deployment.properties.outputs.vm2Name.value)" -ForegroundColor White
    Write-Host "  VM2 Private IP: $($deployment.properties.outputs.vm2PrivateIP.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Network Details:" -ForegroundColor Cyan
    Write-Host "  VNet: $($deployment.properties.outputs.vnetName.value)" -ForegroundColor White
    Write-Host "  Subnet: $($deployment.properties.outputs.subnetName.value)" -ForegroundColor White
    Write-Host "  Accelerated Networking: $($deployment.properties.outputs.acceleratedNetworkingEnabled.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Connect via SSH: ssh $adminUsername@<Public-IP>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "MANA DPDK Setup Notes:" -ForegroundColor Magenta
    Write-Host "  1. Verify MANA hardware: 'lspci -d 1414:00ba'" -ForegroundColor White
    Write-Host "  2. Check kernel version (requires 6.2+ or backported 5.15+): 'uname -r'" -ForegroundColor White
    Write-Host "  3. Install DPDK 22.11+ with net_mana PMD" -ForegroundColor White
    Write-Host "  4. Bind interface using MAC address (not PCI address)" -ForegroundColor White
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
}
