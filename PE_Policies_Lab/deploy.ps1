# ============================================================================
# PE Policies Lab Deployment Script
# ============================================================================
# Deploys Private Endpoint / Private Link Service lab with optional Azure Firewall
#
# Usage:
#   .\deploy.ps1                           # Deploy without Azure Firewall
#   .\deploy.ps1 -DeployAzureFirewall      # Deploy with Azure Firewall
#   .\deploy.ps1 -Cleanup                  # Delete resource group
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-pe-policies-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentPrefix = "pelab",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUsername = "azureuser",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "Wipro@12345678",
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployAzureFirewall,
    
    [Parameter(Mandatory = $false)]
    [switch]$Cleanup
)

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Show-ArchitectureDiagram {
    param([bool]$WithFirewall)
    
    Write-Header "Architecture Diagram"
    
    if ($WithFirewall) {
        Write-Host @"

    WITH AZURE FIREWALL - PE Policies Lab Architecture
    ==================================================
    
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │                         CLIENT VNET (10.10.0.0/16)                          │
    │  ┌──────────────────────────────────────────────────────────────────────┐   │
    │  │  vm-subnet (10.10.0.0/24)                                            │   │
    │  │  ┌─────────────┐                                                     │   │
    │  │  │  Client VM  │ ──────────────┐                                     │   │
    │  │  │  (Windows)  │               │                                     │   │
    │  │  └─────────────┘               │                                     │   │
    │  └────────────────────────────────┼─────────────────────────────────────┘   │
    │                                   │                                         │
    │  ┌────────────────────────────────▼─────────────────────────────────────┐   │
    │  │  AzureFirewallSubnet (10.10.3.0/24)                                  │   │
    │  │  ┌──────────────────────┐                                            │   │
    │  │  │    Azure Firewall    │ (Network Rules: Allow HTTP/HTTPS)          │   │
    │  │  └──────────┬───────────┘                                            │   │
    │  └─────────────┼────────────────────────────────────────────────────────┘   │
    │                │                                                            │
    │  ┌─────────────▼────────────────────────────────────────────────────────┐   │
    │  │  pe-subnet (10.10.1.0/24) [NSG + Route Table + PE Network Policies]  │   │
    │  │  ┌───────────────────────┐                                           │   │
    │  │  │   Private Endpoint    │ ─────────────────┐                        │   │
    │  │  │   (PE to PLS)         │                  │                        │   │
    │  │  └───────────────────────┘                  │                        │   │
    │  └─────────────────────────────────────────────┼────────────────────────┘   │
    │                                                │                            │
    │  ┌─────────────────────────────────────────────┼────────────────────────┐   │
    │  │  AzureBastionSubnet (10.10.2.0/24)          │                        │   │
    │  │  ┌─────────────┐                            │                        │   │
    │  │  │   Bastion   │ (Secure VM Access)         │                        │   │
    │  │  └─────────────┘                            │ Private Link           │   │
    │  └─────────────────────────────────────────────┼────────────────────────┘   │
    └────────────────────────────────────────────────┼────────────────────────────┘
                                                     │
                              ═══════════════════════╪═══════════════════════════
                                    VNet Peering     │    (Firewall Routes)
                              ═══════════════════════╪═══════════════════════════
                                                     │
    ┌────────────────────────────────────────────────┼────────────────────────────┐
    │                        SERVICE VNET (10.20.0.0/16)                          │
    │  ┌─────────────────────────────────────────────┼────────────────────────┐   │
    │  │  pls-subnet (10.20.1.0/24)                  │                        │   │
    │  │  ┌───────────────────────┐                  │                        │   │
    │  │  │ Private Link Service  │ ◄────────────────┘                        │   │
    │  │  │    (PLS to ILB)       │                                           │   │
    │  │  └───────────┬───────────┘                                           │   │
    │  └──────────────┼───────────────────────────────────────────────────────┘   │
    │                 │                                                           │
    │  ┌──────────────▼───────────────────────────────────────────────────────┐   │
    │  │  web-subnet (10.20.0.0/24)                                           │   │
    │  │  ┌───────────────────────┐      ┌─────────────────────────────────┐  │   │
    │  │  │  Internal Load        │──────│        IIS Web Server VM        │  │   │
    │  │  │  Balancer (ILB)       │      │    (Windows Server + IIS)       │  │   │
    │  │  └───────────────────────┘      └─────────────────────────────────┘  │   │
    │  └──────────────────────────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────────────────────────┘

    Traffic Flow:
    Client VM → Route Table → Azure Firewall → Private Endpoint → PLS → ILB → IIS

    PE Network Policies:
    - NSG on pe-subnet controls traffic to Private Endpoint
    - Route Table forces traffic through Azure Firewall
    - privateEndpointNetworkPolicies: 'Enabled'

"@ -ForegroundColor White
    }
    else {
        Write-Host @"

    WITHOUT AZURE FIREWALL - PE Policies Lab Architecture
    =====================================================
    
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │                         CLIENT VNET (10.10.0.0/16)                          │
    │  ┌──────────────────────────────────────────────────────────────────────┐   │
    │  │  vm-subnet (10.10.0.0/24)                                            │   │
    │  │  ┌─────────────┐                                                     │   │
    │  │  │  Client VM  │ ────────────────────────────────────┐               │   │
    │  │  │  (Windows)  │                                     │               │   │
    │  │  └─────────────┘                                     │               │   │
    │  └──────────────────────────────────────────────────────┼───────────────┘   │
    │                                                         │                   │
    │  ┌──────────────────────────────────────────────────────▼───────────────┐   │
    │  │  pe-subnet (10.10.1.0/24) [NSG + PE Network Policies Enabled]        │   │
    │  │  ┌───────────────────────┐                                           │   │
    │  │  │   Private Endpoint    │ ─────────────────────────────────┐        │   │
    │  │  │   (PE to PLS)         │                                  │        │   │
    │  │  └───────────────────────┘                                  │        │   │
    │  └─────────────────────────────────────────────────────────────┼────────┘   │
    │                                                                │            │
    │  ┌─────────────────────────────────────────────────────────────┼────────┐   │
    │  │  AzureBastionSubnet (10.10.2.0/24)                          │        │   │
    │  │  ┌─────────────┐                                            │        │   │
    │  │  │   Bastion   │ (Secure VM Access)                         │        │   │
    │  │  └─────────────┘                             Private Link   │        │   │
    │  └─────────────────────────────────────────────────────────────┼────────┘   │
    └────────────────────────────────────────────────────────────────┼────────────┘
                                                                     │
                              ═══════════════════════════════════════╪════════════
                                    Private Link (No VNet Peering)   │
                              ═══════════════════════════════════════╪════════════
                                                                     │
    ┌────────────────────────────────────────────────────────────────┼────────────┐
    │                        SERVICE VNET (10.20.0.0/16)             │            │
    │  ┌─────────────────────────────────────────────────────────────┼────────┐   │
    │  │  pls-subnet (10.20.1.0/24)                                  │        │   │
    │  │  ┌───────────────────────┐                                  │        │   │
    │  │  │ Private Link Service  │ ◄────────────────────────────────┘        │   │
    │  │  │    (PLS to ILB)       │                                           │   │
    │  │  └───────────┬───────────┘                                           │   │
    │  └──────────────┼───────────────────────────────────────────────────────┘   │
    │                 │                                                           │
    │  ┌──────────────▼───────────────────────────────────────────────────────┐   │
    │  │  web-subnet (10.20.0.0/24)                                           │   │
    │  │  ┌───────────────────────┐      ┌─────────────────────────────────┐  │   │
    │  │  │  Internal Load        │──────│        IIS Web Server VM        │  │   │
    │  │  │  Balancer (ILB)       │      │    (Windows Server + IIS)       │  │   │
    │  │  └───────────────────────┘      └─────────────────────────────────┘  │   │
    │  └──────────────────────────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────────────────────────┘

    Traffic Flow:
    Client VM → Private Endpoint → Private Link Service → Internal LB → IIS

    PE Network Policies:
    - NSG on pe-subnet controls traffic to Private Endpoint
    - privateEndpointNetworkPolicies: 'Enabled' allows NSG rules
    - No Route Table (direct PE connection)

"@ -ForegroundColor White
    }
}

function Show-PostDeploymentInstructions {
    param(
        [string]$ResourceGroup,
        [string]$DeploymentPrefix,
        [bool]$WithFirewall
    )
    
    Write-Header "Post-Deployment Test Instructions"
    
    # Get Private Endpoint IP
    Write-Step "Retrieving Private Endpoint IP address..."
    $peIp = az network private-endpoint show `
        --name "${DeploymentPrefix}-pe" `
        --resource-group $ResourceGroup `
        --query "customDnsConfigs[0].ipAddresses[0]" `
        --output tsv 2>$null
    
    if (-not $peIp) {
        $peIp = az network private-endpoint show `
            --name "${DeploymentPrefix}-pe" `
            --resource-group $ResourceGroup `
            --query "networkInterfaces[0].id" `
            --output tsv 2>$null
        
        if ($peIp) {
            $peIp = az network nic show --ids $peIp --query "ipConfigurations[0].privateIPAddress" --output tsv 2>$null
        }
    }
    
    if (-not $peIp) {
        $peIp = "<PE_IP_ADDRESS>"
        Write-Host "[WARN] Could not retrieve PE IP. Run this to get it:" -ForegroundColor Yellow
        Write-Host "az network private-endpoint show --name ${DeploymentPrefix}-pe --resource-group $ResourceGroup --query networkInterfaces[0].id -o tsv | % { az network nic show --ids `$_ --query ipConfigurations[0].privateIPAddress -o tsv }" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                         TEST ACTION ITEMS                                     " -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Private Endpoint IP: " -NoNewline -ForegroundColor White
    Write-Host $peIp -ForegroundColor Green
    Write-Host ""
    Write-Host "STEP 1: Connect to Client VM via Azure Bastion" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   - Go to Azure Portal → Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "   - Select VM: ${DeploymentPrefix}-client-vm" -ForegroundColor White
    Write-Host "   - Click 'Connect' → 'Bastion'" -ForegroundColor White
    Write-Host "   - Username: $AdminUsername" -ForegroundColor Cyan
    Write-Host "   - Password: (the password you used during deployment)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "STEP 2: Test PE Connectivity from Client VM" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   Open PowerShell on Client VM and run:" -ForegroundColor White
    Write-Host ""
    Write-Host "   # Test 1: Basic connectivity to PE IP" -ForegroundColor Gray
    Write-Host "   Test-NetConnection -ComputerName $peIp -Port 80" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Test 2: HTTP request to IIS via PE" -ForegroundColor Gray
    Write-Host "   Invoke-WebRequest -Uri http://$peIp -UseBasicParsing" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Test 3: View the webpage content" -ForegroundColor Gray
    Write-Host "   (Invoke-WebRequest -Uri http://$peIp -UseBasicParsing).Content" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "STEP 3: Verify PE Network Policies" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "   - In Azure Portal, go to Client VNet → pe-subnet" -ForegroundColor White
    Write-Host "   - Verify 'Private endpoint network policies' is Enabled" -ForegroundColor White
    Write-Host "   - Check NSG '${DeploymentPrefix}-pe-nsg' is attached" -ForegroundColor White
    Write-Host "   - Review NSG rules (AllowHTTPInbound, DenyAllOtherInbound)" -ForegroundColor White
    
    if ($WithFirewall) {
        Write-Host ""
        Write-Host "STEP 4: Verify Firewall Traffic (With Firewall)" -ForegroundColor Yellow
        Write-Host "────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "   - Go to Azure Firewall → Logs" -ForegroundColor White
        Write-Host "   - Check Network Rule logs for HTTP traffic" -ForegroundColor White
        Write-Host "   - Verify traffic from Client VM subnet to Service VNet" -ForegroundColor White
        Write-Host "   - Route Table forces PE traffic through firewall" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                         EXPECTED RESULTS                                      " -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   ✓ Test-NetConnection should show TcpTestSucceeded: True" -ForegroundColor Green
    Write-Host "   ✓ Invoke-WebRequest should return StatusCode: 200" -ForegroundColor Green
    Write-Host "   ✓ Web content should show 'Success! You have reached the IIS Web Server'" -ForegroundColor Green
    Write-Host "   ✓ NSG rules on pe-subnet are applied to PE traffic" -ForegroundColor Green
    if ($WithFirewall) {
        Write-Host "   ✓ Firewall logs show allowed HTTP traffic" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# ============================================================================
# Main Execution
# ============================================================================

$ErrorActionPreference = "Stop"
$startTime = Get-Date

# Handle Cleanup
if ($Cleanup) {
    Write-Header "Cleanup: Deleting Resource Group"
    Write-Step "Deleting resource group: $ResourceGroupName"
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "Resource group deletion initiated. It will be deleted in the background." -ForegroundColor Green
    exit 0
}

# Show Architecture
Show-ArchitectureDiagram -WithFirewall:$DeployAzureFirewall

# Confirm Deployment
Write-Header "Deployment Configuration"
Write-Host "Resource Group    : $ResourceGroupName" -ForegroundColor White
Write-Host "Location          : $Location" -ForegroundColor White
Write-Host "Deployment Prefix : $DeploymentPrefix" -ForegroundColor White
Write-Host "Admin Username    : $AdminUsername" -ForegroundColor White
Write-Host "Azure Firewall    : $(if ($DeployAzureFirewall) { 'Yes' } else { 'No' })" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Proceed with deployment? (y/n)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Check Azure Login
Write-Step "Checking Azure CLI authentication..."
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Running az login..." -ForegroundColor Yellow
    az login --scope https://management.azure.com/.default
}

# Create Resource Group
Write-Step "Creating resource group: $ResourceGroupName"
az group create --name $ResourceGroupName --location $Location --output none

# Deploy Bicep Template
Write-Step "Deploying Bicep template..."
Write-Info "This may take 10-15 minutes (longer with Azure Firewall)"

$deployParams = @(
    "--resource-group", $ResourceGroupName,
    "--template-file", "$PSScriptRoot\main.bicep",
    "--parameters", "deploymentPrefix=$DeploymentPrefix",
    "--parameters", "adminUsername=$AdminUsername",
    "--parameters", "adminPassword=$AdminPassword",
    "--parameters", "location=$Location",
    "--parameters", "deployAzureFirewall=$($DeployAzureFirewall.ToString().ToLower())"
)

az deployment group create @deployParams

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Header "Deployment Completed Successfully!"
Write-Host "Duration: $($duration.Minutes) minutes $($duration.Seconds) seconds" -ForegroundColor Green

# Show Post-Deployment Instructions
Show-PostDeploymentInstructions -ResourceGroup $ResourceGroupName -DeploymentPrefix $DeploymentPrefix -WithFirewall:$DeployAzureFirewall

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green
