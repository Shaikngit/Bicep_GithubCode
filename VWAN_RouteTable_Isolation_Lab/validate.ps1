# ============================================================================
# VWAN Route Table Isolation Lab - Validation Script
# ============================================================================
# This script validates the deployment and checks resource status
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

# ============================================================================
# Functions
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not logged into Azure. Please run 'Connect-AzAccount' first." "ERROR"
            exit 1
        }
        Write-Log "Logged in as: $($context.Account.Id)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error checking Azure login: $_" "ERROR"
        exit 1
    }
}

function Test-ResourceStatus {
    param(
        [string]$ResourceType,
        [string]$ExpectedCount
    )
    
    $resources = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType $ResourceType -ErrorAction SilentlyContinue
    $count = ($resources | Measure-Object).Count
    
    if ($count -eq $ExpectedCount) {
        Write-Log "  ✓ $ResourceType : $count (expected: $ExpectedCount)" "SUCCESS"
        return $true
    }
    else {
        Write-Log "  ✗ $ResourceType : $count (expected: $ExpectedCount)" "ERROR"
        return $false
    }
}

# ============================================================================
# Main Script
# ============================================================================
Write-Log "========================================" "INFO"
Write-Log "VWAN Route Table Isolation Lab Validation" "INFO"
Write-Log "========================================" "INFO"

# Check Azure login
Test-AzureLogin

# Check if resource group exists
Write-Log "" "INFO"
Write-Log "Checking resource group: $ResourceGroupName" "INFO"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Log "Resource group '$ResourceGroupName' does not exist." "ERROR"
    exit 1
}
Write-Log "  ✓ Resource group exists in $($rg.Location)" "SUCCESS"

# ============================================================================
# Validate Resource Counts
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating resource counts..." "INFO"

$allPassed = $true

# Virtual WAN
$allPassed = (Test-ResourceStatus "Microsoft.Network/virtualWans" 1) -and $allPassed

# Virtual Hubs
$allPassed = (Test-ResourceStatus "Microsoft.Network/virtualHubs" 1) -and $allPassed

# VPN Gateways (Hub + 2 Branch)
$allPassed = (Test-ResourceStatus "Microsoft.Network/vpnGateways" 1) -and $allPassed
$allPassed = (Test-ResourceStatus "Microsoft.Network/virtualNetworkGateways" 2) -and $allPassed

# VNets (3 spoke + 2 branch)
$allPassed = (Test-ResourceStatus "Microsoft.Network/virtualNetworks" 5) -and $allPassed

# VMs (5 total)
$allPassed = (Test-ResourceStatus "Microsoft.Compute/virtualMachines" 5) -and $allPassed

# NSGs (5 total)
$allPassed = (Test-ResourceStatus "Microsoft.Network/networkSecurityGroups" 5) -and $allPassed

# Public IPs (2 for branch VPN gateways)
$allPassed = (Test-ResourceStatus "Microsoft.Network/publicIPAddresses" 2) -and $allPassed

# VPN Sites
$allPassed = (Test-ResourceStatus "Microsoft.Network/vpnSites" 2) -and $allPassed

# ============================================================================
# Validate Virtual WAN Components
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating Virtual WAN components..." "INFO"

# Get Virtual WAN
$vwan = Get-AzVirtualWan -ResourceGroupName $ResourceGroupName -Name "vwan-test" -ErrorAction SilentlyContinue
if ($vwan) {
    Write-Log "  ✓ Virtual WAN: $($vwan.Name) - Type: $($vwan.VirtualWANType)" "SUCCESS"
}
else {
    Write-Log "  ✗ Virtual WAN not found" "ERROR"
    $allPassed = $false
}

# Get Virtual Hub
$vhub = Get-AzVirtualHub -ResourceGroupName $ResourceGroupName -Name "vhub-test" -ErrorAction SilentlyContinue
if ($vhub) {
    Write-Log "  ✓ Virtual Hub: $($vhub.Name) - Address: $($vhub.AddressPrefix) - State: $($vhub.ProvisioningState)" "SUCCESS"
}
else {
    Write-Log "  ✗ Virtual Hub not found" "ERROR"
    $allPassed = $false
}

# ============================================================================
# Validate Hub Route Tables
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating Hub Route Tables..." "INFO"

try {
    $routeTables = Get-AzVHubRouteTable -ResourceGroupName $ResourceGroupName -VirtualHubName "vhub-test" -ErrorAction SilentlyContinue
    
    $rtA = $routeTables | Where-Object { $_.Name -eq "RouteTable_A" }
    $rtB = $routeTables | Where-Object { $_.Name -eq "RouteTable_B" }
    $rtDefault = $routeTables | Where-Object { $_.Name -eq "defaultRouteTable" }
    
    if ($rtA) {
        Write-Log "  ✓ RouteTable_A found - State: $($rtA.ProvisioningState)" "SUCCESS"
    }
    else {
        Write-Log "  ✗ RouteTable_A not found" "ERROR"
        $allPassed = $false
    }
    
    if ($rtB) {
        Write-Log "  ✓ RouteTable_B found - State: $($rtB.ProvisioningState)" "SUCCESS"
    }
    else {
        Write-Log "  ✗ RouteTable_B not found" "ERROR"
        $allPassed = $false
    }
    
    if ($rtDefault) {
        Write-Log "  ✓ defaultRouteTable found - State: $($rtDefault.ProvisioningState)" "SUCCESS"
    }
    else {
        Write-Log "  ✓ defaultRouteTable (system managed)" "SUCCESS"
    }
}
catch {
    Write-Log "  ! Could not retrieve route tables: $_" "WARNING"
}

# ============================================================================
# Validate VNet Connections
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating VNet Connections to Hub..." "INFO"

try {
    $connections = Get-AzVirtualHubVnetConnection -ResourceGroupName $ResourceGroupName -VirtualHubName "vhub-test" -ErrorAction SilentlyContinue
    
    foreach ($conn in $connections) {
        $status = if ($conn.ProvisioningState -eq "Succeeded") { "SUCCESS" } else { "WARNING" }
        Write-Log "  ✓ $($conn.Name) - State: $($conn.ProvisioningState)" $status
    }
    
    if (($connections | Measure-Object).Count -eq 3) {
        Write-Log "  ✓ All 3 VNet connections present" "SUCCESS"
    }
    else {
        Write-Log "  ✗ Expected 3 VNet connections, found $(($connections | Measure-Object).Count)" "ERROR"
        $allPassed = $false
    }
}
catch {
    Write-Log "  ! Could not retrieve VNet connections: $_" "WARNING"
}

# ============================================================================
# Validate VPN Gateway Status
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating VPN Gateways..." "INFO"

# Hub VPN Gateway
try {
    $hubVpnGw = Get-AzVpnGateway -ResourceGroupName $ResourceGroupName -Name "vhub-test-vpngw" -ErrorAction SilentlyContinue
    if ($hubVpnGw) {
        Write-Log "  ✓ Hub VPN Gateway: $($hubVpnGw.Name) - State: $($hubVpnGw.ProvisioningState)" "SUCCESS"
    }
    else {
        Write-Log "  ✗ Hub VPN Gateway not found" "ERROR"
        $allPassed = $false
    }
}
catch {
    Write-Log "  ! Could not retrieve Hub VPN Gateway: $_" "WARNING"
}

# Branch VPN Gateways
$branchGateways = @("vpngw-Branch_A", "vpngw-Branch_B")
foreach ($gwName in $branchGateways) {
    $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroupName -Name $gwName -ErrorAction SilentlyContinue
    if ($gw) {
        Write-Log "  ✓ $gwName - State: $($gw.ProvisioningState) - BGP ASN: $($gw.BgpSettings.Asn)" "SUCCESS"
    }
    else {
        Write-Log "  ✗ $gwName not found" "ERROR"
        $allPassed = $false
    }
}

# ============================================================================
# Validate VPN Connections
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating VPN Site Connections..." "INFO"

try {
    $vpnConnections = Get-AzVpnConnection -ResourceGroupName $ResourceGroupName -ParentResourceName "vhub-test-vpngw" -ErrorAction SilentlyContinue
    
    foreach ($vpnConn in $vpnConnections) {
        $status = if ($vpnConn.ConnectionStatus -eq "Connected") { "SUCCESS" } 
                  elseif ($vpnConn.ProvisioningState -eq "Succeeded") { "SUCCESS" }
                  else { "WARNING" }
        Write-Log "  ✓ $($vpnConn.Name) - Provisioning: $($vpnConn.ProvisioningState) - Status: $($vpnConn.ConnectionStatus)" $status
    }
}
catch {
    Write-Log "  ! Could not retrieve VPN connections: $_" "WARNING"
}

# ============================================================================
# Validate VMs
# ============================================================================
Write-Log "" "INFO"
Write-Log "Validating Virtual Machines..." "INFO"

$vmNames = @("vm-a", "vm-b", "vm-c", "vm-branchA", "vm-branchB")
foreach ($vmName in $vmNames) {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status -ErrorAction SilentlyContinue
    if ($vm) {
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        $status = if ($powerState -eq "VM running") { "SUCCESS" } else { "WARNING" }
        
        # Get private IP
        $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.VirtualMachine.Id -eq $vm.Id }
        $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
        
        Write-Log "  ✓ $vmName - $powerState - IP: $privateIp" $status
    }
    else {
        Write-Log "  ✗ $vmName not found" "ERROR"
        $allPassed = $false
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
if ($allPassed) {
    Write-Log "VALIDATION PASSED - All resources deployed successfully!" "SUCCESS"
}
else {
    Write-Log "VALIDATION FAILED - Some resources are missing or in error state" "ERROR"
}
Write-Log "========================================" "INFO"

# ============================================================================
# Display VM IP Summary
# ============================================================================
Write-Log "" "INFO"
Write-Log "VM Private IP Summary:" "INFO"
Write-Log "========================================" "INFO"

$vms = Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
foreach ($vm in $vms) {
    $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.VirtualMachine.Id -eq $vm.Id }
    $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
    Write-Log "  $($vm.Name): $privateIp" "INFO"
}

Write-Log "" "INFO"
Write-Log "To test connectivity, use the IPs above with ping commands." "INFO"
Write-Log "Remember: vm-a should NOT be able to reach vm-branchA/B (and vice versa)" "INFO"

exit $(if ($allPassed) { 0 } else { 1 })
