#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for VM with NAT Gateway and Storage (Modular)

.DESCRIPTION
    This script validates the VM with NAT Gateway and Storage deployment by checking
    all modular components including VM, NAT Gateway, Storage Account, and networking.

.PARAMETER ResourceGroupName
    Name of the resource group to validate (default: rg-vm-natgw-storage)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER SkipConnectivityTests
    Skip network connectivity tests

.PARAMETER Detailed
    Show detailed validation information

.EXAMPLE
    .\validate.ps1 -ResourceGroupName "rg-vm-natgw-storage" -Detailed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-natgw-storage",
    
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

function Test-ModularResources {
    Write-ColorOutput "🏗️  Validating modular resources..." "Cyan"
    $allResources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    
    # Expected resource types for modular deployment
    $expectedTypes = @{
        "Microsoft.Compute/virtualMachines" = "Virtual Machines"
        "Microsoft.Network/natGateways" = "NAT Gateway"
        "Microsoft.Storage/storageAccounts" = "Storage Accounts"
        "Microsoft.Network/virtualNetworks" = "Virtual Networks"
        "Microsoft.Network/publicIPAddresses" = "Public IP Addresses"
        "Microsoft.Network/networkSecurityGroups" = "Network Security Groups"
        "Microsoft.Network/networkInterfaces" = "Network Interfaces"
        "Microsoft.Compute/disks" = "VM Disks"
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

function Test-VMModule {
    Write-ColorOutput "💻 Validating VM module..." "Cyan"
    
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
            }
        }
    }
}

function Test-StorageModule {
    Write-ColorOutput "💾 Validating Storage Account module..." "Cyan"
    
    try {
        $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($sa in $storageAccounts) {
            Write-ColorOutput "   ✅ Storage Account: $($sa.name)" "Green"
            Write-ColorOutput "   📊 Status: $($sa.statusOfPrimary)" "White"
            Write-ColorOutput "   🔐 Access Tier: $($sa.accessTier)" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   🏷️  SKU: $($sa.sku.name)" "White"
                Write-ColorOutput "   🔄 Replication: $($sa.sku.tier)" "White"
                Write-ColorOutput "   🌐 Primary Location: $($sa.primaryLocation)" "White"
                
                # Check blob services
                try {
                    $blobServices = az storage account blob-service-properties show --account-name $sa.name --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
                    if ($blobServices) {
                        Write-ColorOutput "   📦 Blob Service: Enabled" "White"
                    }
                } catch {
                    Write-ColorOutput "   📦 Blob Service: Could not validate" "Yellow"
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate storage account details" "Yellow"
    }
}

function Test-NATGateway {
    Write-ColorOutput "🌐 Validating NAT Gateway..." "Cyan"
    
    try {
        $natGateways = az network nat gateway list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($natgw in $natGateways) {
            Write-ColorOutput "   ✅ NAT Gateway: $($natgw.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($natgw.provisioningState)" "White"
            Write-ColorOutput "   ⏱️  Idle Timeout: $($natgw.idleTimeoutInMinutes) minutes" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   🏷️  SKU: $($natgw.sku.name)" "White"
                
                # Check associated public IPs
                if ($natgw.publicIpAddresses) {
                    Write-ColorOutput "   🌍 Public IPs: $($natgw.publicIpAddresses.Count)" "White"
                    foreach ($pip in $natgw.publicIpAddresses) {
                        $pipName = $pip.id.Split('/')[-1]
                        Write-ColorOutput "     - $pipName" "White"
                    }
                }
                
                # Check associated subnets
                if ($natgw.subnets) {
                    Write-ColorOutput "   🏠 Associated Subnets: $($natgw.subnets.Count)" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate NAT Gateway details" "Yellow"
    }
}

function Test-NetworkConnectivity {
    if ($SkipConnectivityTests) {
        Write-ColorOutput "⏭️  Skipping network connectivity tests" "Yellow"
        return
    }
    
    Write-ColorOutput "🌐 Testing network connectivity..." "Cyan"
    
    # Test VNet and subnet configuration
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
                    
                    # Check NAT Gateway association
                    if ($subnet.natGateway) {
                        $natGwName = $subnet.natGateway.id.Split('/')[-1]
                        Write-ColorOutput "     🌐 NAT Gateway: $natGwName" "White"
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
            "NAT Gateway" { $totalCost += 45 }
            "Virtual Machines" { $totalCost += ($result.Count * 35) }
            "Storage Accounts" { $totalCost += ($result.Count * 20) }
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
Write-ColorOutput "✅ VM with NAT Gateway and Storage (Modular) Validation" "Cyan"
Write-ColorOutput "=======================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

if (-not (Test-ResourceGroupExists)) { exit 1 }

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VALIDATING: MODULAR VM WITH NAT GATEWAY AND STORAGE" "Cyan"
Write-ColorOutput "=======================================================" "Cyan"

$deploymentInfo = Get-DeploymentInfo
$validationResults = Test-ModularResources

Write-ColorOutput "" "White"
Test-VMModule
Write-ColorOutput "" "White"
Test-StorageModule
Write-ColorOutput "" "White"
Test-NATGateway
Write-ColorOutput "" "White"
Test-NetworkConnectivity

Write-ColorOutput "" "White"
Show-ValidationSummary -Results $validationResults

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Validation completed!" "Green"
Write-ColorOutput "💡 Use -Detailed for more comprehensive information" "Cyan"
Write-ColorOutput "💡 Use -SkipConnectivityTests to skip network tests" "Cyan"