#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for Private Endpoint with Public Load Balancer VM

.DESCRIPTION
    This script validates the Private Endpoint with Public Load Balancer VM deployment by checking
    VMs, load balancers, private endpoints, networking, and load balancing configuration.

.PARAMETER ResourceGroupName
    Name of the resource group to validate (default: rg-pe-plb-vm)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER SkipConnectivityTests
    Skip network connectivity tests

.PARAMETER Detailed
    Show detailed validation information

.EXAMPLE
    .\validate.ps1 -ResourceGroupName "rg-pe-plb-vm" -Detailed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-plb-vm",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipConnectivityTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Helper functions
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-AzureConnection {
    Write-ColorOutput "🔍 Checking Azure connection..." "Cyan"
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Connected to Azure as: $($account.user.name)" "Green"
        return $true
    } catch {
        Write-ColorOutput "❌ Not connected to Azure. Please run 'az login'" "Red"
        return $false
    }
}

function Test-ResourceGroupExists {
    try {
        $rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
        if ($rg) {
            Write-ColorOutput "✅ Resource group found: $ResourceGroupName" "Green"
            if ($Detailed) { Write-ColorOutput "   📍 Location: $($rg.location)" "White" }
            return $true
        }
    } catch {}
    Write-ColorOutput "❌ Resource group not found: $ResourceGroupName" "Red"
    return $false
}

function Get-DeploymentInfo {
    try {
        Write-ColorOutput "📋 Getting deployment information..." "Cyan"
        $deployments = az deployment group list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        $latestDeployment = $deployments | Sort-Object properties.timestamp -Descending | Select-Object -First 1
        
        if ($latestDeployment) {
            Write-ColorOutput "✅ Latest deployment: $($latestDeployment.name)" "Green"
            if ($Detailed) {
                Write-ColorOutput "   📅 Timestamp: $($latestDeployment.properties.timestamp)" "White"
                Write-ColorOutput "   📊 Status: $($latestDeployment.properties.provisioningState)" "White"
                Write-ColorOutput "   ⏱️  Duration: $($latestDeployment.properties.duration)" "White"
            }
            return $latestDeployment
        }
    } catch {
        Write-ColorOutput "⚠️  Could not retrieve deployment information" "Yellow"
    }
    return $null
}

function Test-InfrastructureResources {
    Write-ColorOutput "🏗️  Validating infrastructure resources..." "Cyan"
    $allResources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    
    # Expected resource types for PE + Public LB deployment
    $expectedTypes = @{
        "Microsoft.Compute/virtualMachines" = "Virtual Machines"
        "Microsoft.Network/loadBalancers" = "Load Balancers"
        "Microsoft.Network/privateEndpoints" = "Private Endpoints"
        "Microsoft.Network/virtualNetworks" = "Virtual Networks"
        "Microsoft.Network/publicIPAddresses" = "Public IP Addresses"
        "Microsoft.Network/networkSecurityGroups" = "Network Security Groups"
        "Microsoft.Network/networkInterfaces" = "Network Interfaces"
        "Microsoft.Compute/disks" = "VM Disks"
        "Microsoft.Network/privateLinkServices" = "Private Link Services"
    }
    
    $validationResults = @()
    
    foreach ($type in $expectedTypes.GetEnumerator()) {
        $resources = $allResources | Where-Object { $_.type -eq $type.Key }
        if ($resources.Count -gt 0) {
            Write-ColorOutput "✅ $($type.Value): $($resources.Count) found" "Green"
            if ($Detailed) {
                foreach ($resource in $resources) {
                    Write-ColorOutput "   📦 $($resource.name)" "White"
                }
            }
            $validationResults += @{Type = $type.Value; Status = "Found"; Count = $resources.Count}
        } else {
            Write-ColorOutput "⚠️  $($type.Value): Not found" "Yellow"
            $validationResults += @{Type = $type.Value; Status = "Missing"; Count = 0}
        }
    }
    
    return $validationResults
}

function Test-VirtualMachines {
    Write-ColorOutput "💻 Validating virtual machines..." "Cyan"
    
    $vms = az vm list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    foreach ($vm in $vms) {
        $vmStatus = az vm get-instance-view --resource-group $ResourceGroupName --name $vm.name --output json | ConvertFrom-Json
        $powerState = ($vmStatus.instanceView.statuses | Where-Object { $_.code -like "PowerState/*" }).displayStatus
        
        Write-ColorOutput "   ✅ VM: $($vm.name)" "Green"
        Write-ColorOutput "   🔋 Power State: $powerState" "White"
        Write-ColorOutput "   💾 VM Size: $($vm.hardwareProfile.vmSize)" "White"
        
        if ($Detailed) {
            Write-ColorOutput "   📍 Location: $($vm.location)" "White"
            Write-ColorOutput "   🖥️  OS Type: $($vm.storageProfile.osDisk.osType)" "White"
            
            # Check VM network interfaces
            $networkProfile = $vm.networkProfile.networkInterfaces
            if ($networkProfile) {
                Write-ColorOutput "   🌐 Network Interfaces: $($networkProfile.Count)" "White"
                foreach ($nic in $networkProfile) {
                    $nicName = $nic.id.Split('/')[-1]
                    Write-ColorOutput "     - $nicName" "White"
                }
            }
        }
    }
}

function Test-LoadBalancers {
    Write-ColorOutput "⚖️  Validating load balancers..." "Cyan"
    
    try {
        $loadBalancers = az network lb list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($lb in $loadBalancers) {
            Write-ColorOutput "   ✅ Load Balancer: $($lb.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($lb.provisioningState)" "White"
            Write-ColorOutput "   🏷️  SKU: $($lb.sku.name)" "White"
            
            if ($Detailed) {
                # Check frontend IP configurations
                if ($lb.frontendIPConfigurations) {
                    Write-ColorOutput "   🌐 Frontend IPs: $($lb.frontendIPConfigurations.Count)" "White"
                    foreach ($frontend in $lb.frontendIPConfigurations) {
                        Write-ColorOutput "     - $($frontend.name): $($frontend.provisioningState)" "White"
                        if ($frontend.publicIPAddress) {
                            $pipName = $frontend.publicIPAddress.id.Split('/')[-1]
                            Write-ColorOutput "       Public IP: $pipName" "White"
                        }
                    }
                }
                
                # Check backend address pools
                if ($lb.backendAddressPools) {
                    Write-ColorOutput "   🎯 Backend Pools: $($lb.backendAddressPools.Count)" "White"
                    foreach ($backend in $lb.backendAddressPools) {
                        Write-ColorOutput "     - $($backend.name): $($backend.provisioningState)" "White"
                        if ($backend.backendIPConfigurations) {
                            Write-ColorOutput "       Backend IPs: $($backend.backendIPConfigurations.Count)" "White"
                        }
                    }
                }
                
                # Check load balancing rules
                if ($lb.loadBalancingRules) {
                    Write-ColorOutput "   📋 LB Rules: $($lb.loadBalancingRules.Count)" "White"
                    foreach ($rule in $lb.loadBalancingRules) {
                        Write-ColorOutput "     - $($rule.name): $($rule.protocol):$($rule.frontendPort)→$($rule.backendPort)" "White"
                    }
                }
                
                # Check health probes
                if ($lb.probes) {
                    Write-ColorOutput "   🩺 Health Probes: $($lb.probes.Count)" "White"
                    foreach ($probe in $lb.probes) {
                        Write-ColorOutput "     - $($probe.name): $($probe.protocol):$($probe.port)" "White"
                    }
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate load balancer details" "Yellow"
    }
}

function Test-PrivateEndpoints {
    Write-ColorOutput "🔒 Validating private endpoints..." "Cyan"
    
    try {
        $privateEndpoints = az network private-endpoint list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($pe in $privateEndpoints) {
            Write-ColorOutput "   ✅ Private Endpoint: $($pe.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($pe.provisioningState)" "White"
            
            if ($Detailed) {
                # Check private link service connections
                if ($pe.privateLinkServiceConnections) {
                    Write-ColorOutput "   🔗 Service Connections: $($pe.privateLinkServiceConnections.Count)" "White"
                    foreach ($connection in $pe.privateLinkServiceConnections) {
                        Write-ColorOutput "     - $($connection.name): $($connection.privateLinkServiceConnectionState.status)" "White"
                        if ($connection.privateLinkServiceId) {
                            $serviceName = $connection.privateLinkServiceId.Split('/')[-1]
                            Write-ColorOutput "       Service: $serviceName" "White"
                        }
                    }
                }
                
                # Check network interfaces
                if ($pe.networkInterfaces) {
                    Write-ColorOutput "   🌐 Network Interfaces: $($pe.networkInterfaces.Count)" "White"
                }
                
                # Check private DNS zones
                $privateDnsZones = az network private-dns zone list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
                if ($privateDnsZones) {
                    Write-ColorOutput "   🌐 Private DNS Zones:" "White"
                    foreach ($zone in $privateDnsZones) {
                        Write-ColorOutput "     - $($zone.name)" "White"
                    }
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate private endpoint details" "Yellow"
    }
}

function Test-PrivateLinkServices {
    Write-ColorOutput "🔗 Validating private link services..." "Cyan"
    
    try {
        $privateLinkServices = az network private-link-service list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($pls in $privateLinkServices) {
            Write-ColorOutput "   ✅ Private Link Service: $($pls.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($pls.provisioningState)" "White"
            
            if ($Detailed) {
                # Check load balancer frontend IP configurations
                if ($pls.loadBalancerFrontendIpConfigurations) {
                    Write-ColorOutput "   ⚖️  LB Frontend IPs: $($pls.loadBalancerFrontendIpConfigurations.Count)" "White"
                }
                
                # Check IP configurations
                if ($pls.ipConfigurations) {
                    Write-ColorOutput "   🌐 IP Configurations: $($pls.ipConfigurations.Count)" "White"
                }
                
                # Check private endpoint connections
                if ($pls.privateEndpointConnections) {
                    Write-ColorOutput "   🔒 PE Connections: $($pls.privateEndpointConnections.Count)" "White"
                    foreach ($peConn in $pls.privateEndpointConnections) {
                        Write-ColorOutput "     - $($peConn.name): $($peConn.privateLinkServiceConnectionState.status)" "White"
                    }
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate private link service details" "Yellow"
    }
}

function Test-NetworkConnectivity {
    if ($SkipConnectivityTests) {
        Write-ColorOutput "⏭️  Skipping network connectivity tests" "Yellow"
        return
    }
    
    Write-ColorOutput "🌐 Testing network connectivity..." "Cyan"
    
    # Test VNet configuration
    try {
        $vnets = az network vnet list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($vnet in $vnets) {
            Write-ColorOutput "   ✅ VNet: $($vnet.name)" "Green"
            Write-ColorOutput "   📍 Address Space: $($vnet.addressSpace.addressPrefixes -join ', ')" "White"
            
            if ($Detailed) {
                # Check subnets
                foreach ($subnet in $vnet.subnets) {
                    Write-ColorOutput "   🏠 Subnet: $($subnet.name)" "White"
                    Write-ColorOutput "     📍 Address Prefix: $($subnet.addressPrefix)" "White"
                    
                    # Check subnet associations
                    if ($subnet.networkSecurityGroup) {
                        $nsgName = $subnet.networkSecurityGroup.id.Split('/')[-1]
                        Write-ColorOutput "     🛡️  NSG: $nsgName" "White"
                    }
                    
                    # Check private endpoints in subnet
                    if ($subnet.privateEndpoints) {
                        Write-ColorOutput "     🔒 Private Endpoints: $($subnet.privateEndpoints.Count)" "White"
                    }
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not test VNet configuration" "Yellow"
    }
    
    # Test public IP addresses
    try {
        $publicIPs = az network public-ip list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($pip in $publicIPs) {
            Write-ColorOutput "   ✅ Public IP: $($pip.name)" "Green"
            Write-ColorOutput "   🌍 IP Address: $($pip.ipAddress)" "White"
            Write-ColorOutput "   🏷️  SKU: $($pip.sku.name)" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   📊 Provisioning State: $($pip.provisioningState)" "White"
                Write-ColorOutput "   🔄 Allocation Method: $($pip.publicIPAllocationMethod)" "White"
                
                # Check if associated with load balancer
                if ($pip.ipConfiguration) {
                    $associatedResource = $pip.ipConfiguration.id.Split('/')[-3]
                    Write-ColorOutput "   🔗 Associated with: $associatedResource" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate public IP addresses" "Yellow"
    }
}

function Show-ValidationSummary {
    param([array]$Results)
    
    Write-ColorOutput "📊 VALIDATION SUMMARY" "Cyan"
    Write-ColorOutput "=====================" "Cyan"
    
    $foundCount = ($Results | Where-Object { $_.Status -eq "Found" }).Count
    $missingCount = ($Results | Where-Object { $_.Status -eq "Missing" }).Count
    
    Write-ColorOutput "✅ Resources Found: $foundCount" "Green"
    if ($missingCount -gt 0) {
        Write-ColorOutput "⚠️  Resources Missing: $missingCount" "Yellow"
    }
    
    # Calculate estimated monthly cost
    $totalCost = 0
    foreach ($result in $Results | Where-Object { $_.Status -eq "Found" }) {
        switch ($result.Type) {
            "Load Balancers" { $totalCost += ($result.Count * 20) }
            "Virtual Machines" { $totalCost += ($result.Count * 35) }
            "Private Endpoints" { $totalCost += ($result.Count * 7) }
            "Private Link Services" { $totalCost += ($result.Count * 7) }
            "Public IP Addresses" { $totalCost += ($result.Count * 4) }
            "Virtual Networks" { $totalCost += 5 }
        }
    }
    
    if ($totalCost -gt 0) {
        Write-ColorOutput "💰 Estimated Monthly Cost: ~$$totalCost" "Yellow"
    }
    
    $overallStatus = if ($missingCount -eq 0) { "HEALTHY" } else { "NEEDS ATTENTION" }
    $color = if ($missingCount -eq 0) { "Green" } else { "Yellow" }
    Write-ColorOutput "🎯 Overall Status: $overallStatus" $color
}

# Main script
Write-ColorOutput "✅ Private Endpoint with Public Load Balancer VM Validation" "Cyan"
Write-ColorOutput "===========================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

if (-not (Test-ResourceGroupExists)) { exit 1 }

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VALIDATING: PRIVATE ENDPOINT WITH PUBLIC LOAD BALANCER VM" "Cyan"
Write-ColorOutput "=============================================================" "Cyan"

$deploymentInfo = Get-DeploymentInfo
$validationResults = Test-InfrastructureResources

Write-ColorOutput "" "White"
Test-VirtualMachines
Write-ColorOutput "" "White"
Test-LoadBalancers
Write-ColorOutput "" "White"
Test-PrivateEndpoints
Write-ColorOutput "" "White"
Test-PrivateLinkServices
Write-ColorOutput "" "White"
Test-NetworkConnectivity

Write-ColorOutput "" "White"
Show-ValidationSummary -Results $validationResults

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Validation completed!" "Green"
Write-ColorOutput "💡 Use -Detailed for more comprehensive information" "Cyan"
Write-ColorOutput "💡 Use -SkipConnectivityTests to skip network tests" "Cyan"