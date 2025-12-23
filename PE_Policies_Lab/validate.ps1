# ============================================================================
# PE Policies Lab Validation Script
# ============================================================================
# Validates the PE/PLS lab deployment and PE Network Policies configuration
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-pe-policies-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentPrefix = "pelab"
)

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Result {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    if ($Passed) {
        Write-Host "✅ PASS: $Test" -ForegroundColor Green
    }
    else {
        Write-Host "❌ FAIL: $Test" -ForegroundColor Red
    }
    
    if ($Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# ============================================================================
# Main Validation
# ============================================================================

$ErrorActionPreference = "Continue"
$passedTests = 0
$failedTests = 0

Write-Header "PE Policies Lab Validation"

# Check Azure Login
Write-Host ""
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Cyan
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Please run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "Authenticated successfully." -ForegroundColor Green

# Check Resource Group
Write-Header "Resource Group Validation"
$rg = az group show --name $ResourceGroupName --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Resource Group Exists" -Passed $true -Details $ResourceGroupName
    $passedTests++
}
else {
    Write-Result -Test "Resource Group Exists" -Passed $false -Details "Resource group not found"
    $failedTests++
    exit 1
}

# Validate VNets
Write-Header "Virtual Network Validation"

$clientVnet = az network vnet show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-client-vnet" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Client VNet Exists" -Passed $true -Details "${DeploymentPrefix}-client-vnet"
    $passedTests++
}
else {
    Write-Result -Test "Client VNet Exists" -Passed $false
    $failedTests++
}

$serviceVnet = az network vnet show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-service-vnet" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Service VNet Exists" -Passed $true -Details "${DeploymentPrefix}-service-vnet"
    $passedTests++
}
else {
    Write-Result -Test "Service VNet Exists" -Passed $false
    $failedTests++
}

# Validate PE Network Policies
Write-Header "PE Network Policies Validation"

$peSubnetPolicies = az network vnet subnet show `
    --resource-group $ResourceGroupName `
    --vnet-name "${DeploymentPrefix}-client-vnet" `
    --name "pe-subnet" `
    --query "privateEndpointNetworkPolicies" -o tsv 2>&1

if ($peSubnetPolicies -eq "Enabled") {
    Write-Result -Test "PE Network Policies Enabled on pe-subnet" -Passed $true -Details "privateEndpointNetworkPolicies: Enabled"
    $passedTests++
}
else {
    Write-Result -Test "PE Network Policies Enabled on pe-subnet" -Passed $false -Details "Expected 'Enabled', got '$peSubnetPolicies'"
    $failedTests++
}

# Check NSG on PE Subnet
$peSubnetNsg = az network vnet subnet show `
    --resource-group $ResourceGroupName `
    --vnet-name "${DeploymentPrefix}-client-vnet" `
    --name "pe-subnet" `
    --query "networkSecurityGroup.id" -o tsv 2>&1

if ($peSubnetNsg -and $peSubnetNsg -ne "null") {
    Write-Result -Test "NSG Attached to pe-subnet" -Passed $true -Details "NSG is attached"
    $passedTests++
}
else {
    Write-Result -Test "NSG Attached to pe-subnet" -Passed $false -Details "No NSG found"
    $failedTests++
}

# Validate Private Link Service
Write-Header "Private Link Service Validation"

$pls = az network private-link-service show `
    --resource-group $ResourceGroupName `
    --name "${DeploymentPrefix}-pls" `
    --query name -o tsv 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Private Link Service Exists" -Passed $true -Details "${DeploymentPrefix}-pls"
    $passedTests++
}
else {
    Write-Result -Test "Private Link Service Exists" -Passed $false
    $failedTests++
}

# Validate Private Endpoint
Write-Header "Private Endpoint Validation"

$pe = az network private-endpoint show `
    --resource-group $ResourceGroupName `
    --name "${DeploymentPrefix}-pe" `
    --query name -o tsv 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Private Endpoint Exists" -Passed $true -Details "${DeploymentPrefix}-pe"
    $passedTests++
    
    # Get PE IP
    $peNicId = az network private-endpoint show `
        --resource-group $ResourceGroupName `
        --name "${DeploymentPrefix}-pe" `
        --query "networkInterfaces[0].id" -o tsv 2>&1
    
    if ($peNicId) {
        $peIp = az network nic show --ids $peNicId --query "ipConfigurations[0].privateIPAddress" -o tsv 2>&1
        Write-Result -Test "Private Endpoint IP Retrieved" -Passed $true -Details "IP: $peIp"
        $passedTests++
    }
}
else {
    Write-Result -Test "Private Endpoint Exists" -Passed $false
    $failedTests++
}

# Validate VMs
Write-Header "Virtual Machine Validation"

$clientVm = az vm show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-client-vm" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Client VM Exists" -Passed $true -Details "${DeploymentPrefix}-client-vm"
    $passedTests++
}
else {
    Write-Result -Test "Client VM Exists" -Passed $false
    $failedTests++
}

$webVm = az vm show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-web-vm" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Web Server VM Exists" -Passed $true -Details "${DeploymentPrefix}-web-vm"
    $passedTests++
}
else {
    Write-Result -Test "Web Server VM Exists" -Passed $false
    $failedTests++
}

# Validate Bastion
Write-Header "Bastion Validation"

$bastion = az network bastion show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-bastion" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Azure Bastion Exists" -Passed $true -Details "${DeploymentPrefix}-bastion"
    $passedTests++
}
else {
    Write-Result -Test "Azure Bastion Exists" -Passed $false
    $failedTests++
}

# Validate Internal Load Balancer
Write-Header "Load Balancer Validation"

$ilb = az network lb show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-ilb" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Internal Load Balancer Exists" -Passed $true -Details "${DeploymentPrefix}-ilb"
    $passedTests++
}
else {
    Write-Result -Test "Internal Load Balancer Exists" -Passed $false
    $failedTests++
}

# Check for Optional Azure Firewall
Write-Header "Optional Azure Firewall Check"

$fw = az network firewall show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-fw" --query name -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result -Test "Azure Firewall Deployed" -Passed $true -Details "${DeploymentPrefix}-fw (Optional feature enabled)"
    $passedTests++
    
    # Check Route Table
    $rt = az network route-table show --resource-group $ResourceGroupName --name "${DeploymentPrefix}-rt-pe-subnet" --query name -o tsv 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Result -Test "Route Table for PE Subnet" -Passed $true -Details "Traffic routed through firewall"
        $passedTests++
    }
}
else {
    Write-Host "ℹ️  Azure Firewall not deployed (optional feature)" -ForegroundColor Gray
}

# Summary
Write-Header "Validation Summary"
Write-Host ""
Write-Host "Passed Tests: $passedTests" -ForegroundColor Green
Write-Host "Failed Tests: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✅ All validations passed! Lab is ready for testing." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Connect to Client VM via Bastion" -ForegroundColor White
    Write-Host "2. Test connectivity to PE IP using:" -ForegroundColor White
    Write-Host "   Test-NetConnection -ComputerName $peIp -Port 80" -ForegroundColor Cyan
    Write-Host "   Invoke-WebRequest -Uri http://$peIp -UseBasicParsing" -ForegroundColor Cyan
}
else {
    Write-Host "⚠️  Some validations failed. Please check the deployment." -ForegroundColor Yellow
}
