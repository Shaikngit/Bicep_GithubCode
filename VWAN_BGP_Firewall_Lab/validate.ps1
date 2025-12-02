# ============================================================================
# VWAN BGP Lab - Validation Script
# ============================================================================
# This script validates the deployment and checks connectivity status
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-vwan-bgp-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentPrefix = "vwan-bgp"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VWAN BGP Lab Validation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if logged in to Azure
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged in to Azure. Please login..." -ForegroundColor Yellow
    Connect-AzAccount
}

Write-Host "`nValidating resources in: $ResourceGroupName" -ForegroundColor Yellow

$allPassed = $true

# Function to check resource
function Test-Resource {
    param($ResourceType, $ResourceName, $Description)
    
    try {
        $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
        if ($resource) {
            Write-Host "[PASS] $Description - $ResourceName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[FAIL] $Description - $ResourceName not found" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[FAIL] $Description - Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n=== Checking Core Resources ===" -ForegroundColor Cyan

# Virtual WAN
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualWans" -ResourceName "$DeploymentPrefix-vwan" -Description "Virtual WAN") -and $allPassed

# Virtual Hub
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualHubs" -ResourceName "$DeploymentPrefix-hub-sea" -Description "Virtual Hub") -and $allPassed

# Hub VPN Gateway
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/vpnGateways" -ResourceName "$DeploymentPrefix-hub-vpngw" -Description "Hub VPN Gateway") -and $allPassed

# Azure Firewall
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/azureFirewalls" -ResourceName "$DeploymentPrefix-hub-fw" -Description "Azure Firewall") -and $allPassed

Write-Host "`n=== Checking VNets ===" -ForegroundColor Cyan

# Spoke VNets
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualNetworks" -ResourceName "$DeploymentPrefix-vnet-spoke1" -Description "Spoke 1 VNet") -and $allPassed
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualNetworks" -ResourceName "$DeploymentPrefix-vnet-spoke2" -Description "Spoke 2 VNet") -and $allPassed
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualNetworks" -ResourceName "$DeploymentPrefix-vnet-onprem" -Description "On-Prem VNet") -and $allPassed

Write-Host "`n=== Checking VPN Resources ===" -ForegroundColor Cyan

# On-Prem VPN Gateway
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/virtualNetworkGateways" -ResourceName "$DeploymentPrefix-onprem-vpngw" -Description "On-Prem VPN Gateway") -and $allPassed

# VPN Site
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/vpnSites" -ResourceName "$DeploymentPrefix-vpnsite-onprem" -Description "VPN Site") -and $allPassed

Write-Host "`n=== Checking Bastion Hosts ===" -ForegroundColor Cyan

$allPassed = (Test-Resource -ResourceType "Microsoft.Network/bastionHosts" -ResourceName "$DeploymentPrefix-bastion-spoke1" -Description "Bastion (Spoke 1)") -and $allPassed
$allPassed = (Test-Resource -ResourceType "Microsoft.Network/bastionHosts" -ResourceName "$DeploymentPrefix-bastion-onprem" -Description "Bastion (On-Prem)") -and $allPassed

Write-Host "`n=== Checking VMs ===" -ForegroundColor Cyan

$allPassed = (Test-Resource -ResourceType "Microsoft.Compute/virtualMachines" -ResourceName "$DeploymentPrefix-vm-spoke1" -Description "Spoke 1 VM") -and $allPassed
$allPassed = (Test-Resource -ResourceType "Microsoft.Compute/virtualMachines" -ResourceName "$DeploymentPrefix-vm-spoke2" -Description "Spoke 2 VM") -and $allPassed
$allPassed = (Test-Resource -ResourceType "Microsoft.Compute/virtualMachines" -ResourceName "$DeploymentPrefix-vm-onprem" -Description "On-Prem VM") -and $allPassed

Write-Host "`n=== Checking VPN Connection Status ===" -ForegroundColor Cyan

try {
    $vpnConnection = Get-AzVpnConnection -ResourceGroupName $ResourceGroupName -ParentResourceName "$DeploymentPrefix-hub-vpngw" -Name "conn-to-onprem" -ErrorAction SilentlyContinue
    if ($vpnConnection) {
        $status = $vpnConnection.ConnectionStatus
        if ($status -eq "Connected") {
            Write-Host "[PASS] VPN Connection Status: $status" -ForegroundColor Green
        } elseif ($status -eq "Connecting") {
            Write-Host "[WAIT] VPN Connection Status: $status (still establishing)" -ForegroundColor Yellow
        } else {
            Write-Host "[WARN] VPN Connection Status: $status" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[FAIL] VPN Connection not found" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "[WARN] Could not check VPN connection status: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Checking BGP Status ===" -ForegroundColor Cyan

try {
    $onPremGw = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroupName -Name "$DeploymentPrefix-onprem-vpngw" -ErrorAction SilentlyContinue
    if ($onPremGw -and $onPremGw.BgpSettings) {
        Write-Host "[INFO] On-Prem Gateway BGP ASN: $($onPremGw.BgpSettings.Asn)" -ForegroundColor Cyan
        Write-Host "[INFO] On-Prem Gateway BGP Peer IP: $($onPremGw.BgpSettings.BgpPeeringAddress)" -ForegroundColor Cyan
        
        # Try to get BGP peer status
        try {
            $bgpPeers = Get-AzVirtualNetworkGatewayBGPPeerStatus -ResourceGroupName $ResourceGroupName -VirtualNetworkGatewayName "$DeploymentPrefix-onprem-vpngw"
            if ($bgpPeers) {
                foreach ($peer in $bgpPeers) {
                    $peerStatus = $peer.State
                    if ($peerStatus -eq "Connected") {
                        Write-Host "[PASS] BGP Peer $($peer.Neighbor): $peerStatus" -ForegroundColor Green
                    } else {
                        Write-Host "[WARN] BGP Peer $($peer.Neighbor): $peerStatus" -ForegroundColor Yellow
                    }
                }
            }
        } catch {
            Write-Host "[INFO] BGP peer status not available yet (gateway may still be initializing)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "[WARN] Could not check BGP status: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Checking Learned Routes ===" -ForegroundColor Cyan

try {
    $learnedRoutes = Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $ResourceGroupName -VirtualNetworkGatewayName "$DeploymentPrefix-onprem-vpngw" -ErrorAction SilentlyContinue
    if ($learnedRoutes) {
        Write-Host "[INFO] Routes learned by On-Prem Gateway:" -ForegroundColor Cyan
        $learnedRoutes | Where-Object { $_.Origin -eq "EBgp" } | ForEach-Object {
            Write-Host "       Network: $($_.Network), NextHop: $($_.NextHop), Origin: $($_.Origin)" -ForegroundColor White
        }
        
        # Check for expected prefixes
        $expectedPrefixes = @("10.20.0.0/16", "10.30.0.0/16", "10.10.0.0/24")
        foreach ($prefix in $expectedPrefixes) {
            $found = $learnedRoutes | Where-Object { $_.Network -eq $prefix }
            if ($found) {
                Write-Host "[PASS] Route $prefix learned via BGP" -ForegroundColor Green
            } else {
                Write-Host "[WAIT] Route $prefix not yet learned (BGP may still be converging)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "[INFO] Learned routes not available yet (BGP may still be initializing)" -ForegroundColor Yellow
}

Write-Host "`n=== Checking VM Network Info ===" -ForegroundColor Cyan

$vmNames = @("$DeploymentPrefix-vm-spoke1", "$DeploymentPrefix-vm-spoke2", "$DeploymentPrefix-vm-onprem")
foreach ($vmName in $vmNames) {
    try {
        $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "*$vmName*" }
        if ($nic) {
            $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
            Write-Host "[INFO] $vmName Private IP: $privateIp" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[WARN] Could not get IP for $vmName" -ForegroundColor Yellow
    }
}

Write-Host "`n============================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "All core resources validated successfully!" -ForegroundColor Green
} else {
    Write-Host "Some resources are missing or failed validation." -ForegroundColor Yellow
    Write-Host "Check the deployment status and try again." -ForegroundColor Yellow
}
Write-Host "============================================" -ForegroundColor Cyan

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host @"
1. If VPN is 'Connecting', wait a few more minutes for it to establish
2. Once VPN is 'Connected', BGP routes should propagate within 1-2 minutes
3. Use Azure Bastion to connect to VMs and test connectivity:
   - From On-Prem VM: ping <spoke1-ip>, ping <spoke2-ip>
   - From Spoke1 VM: ping <onprem-ip>, ping <spoke2-ip>
"@
