#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for VM and Storage Same Region (Modular)

.DESCRIPTION
    This script validates the VM and Storage Same Region deployment by checking
    all modular components including VM, Storage Account, and networking with
    focus on same-region co-location verification.

.PARAMETER ResourceGroupName
    Name of the resource group to validate (default: rg-vm-storage-sameregion)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER SkipConnectivityTests
    Skip network connectivity tests

.PARAMETER Detailed
    Show detailed validation information

.EXAMPLE
    .\validate.ps1 -ResourceGroupName "rg-vm-storage-sameregion" -Detailed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-storage-sameregion",
    
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
            return $rg
        }
    } catch {}
    Write-ColorOutput "❌ Resource group not found: $ResourceGroupName" "Red"
    return $null
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
    Write-ColorOutput "💻 Validating Windows VM module..." "Cyan"
    
    $vms = az vm list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    foreach ($vm in $vms) {
        $vmStatus = az vm get-instance-view --resource-group $ResourceGroupName --name $vm.name --output json | ConvertFrom-Json
        $powerState = ($vmStatus.instanceView.statuses | Where-Object { $_.code -like "PowerState/*" }).displayStatus
        
        Write-ColorOutput "   ✅ VM: $($vm.name)" "Green"
        Write-ColorOutput "   🔋 Power State: $powerState" "White"
        Write-ColorOutput "   💾 VM Size: $($vm.hardwareProfile.vmSize)" "White"
        Write-ColorOutput "   📍 Location: $($vm.location)" "White"
        
        if ($Detailed) {
            Write-ColorOutput "   🖥️  OS Type: $($vm.storageProfile.osDisk.osType)" "White"
            Write-ColorOutput "   🔐 Admin Username: $($vm.osProfile.adminUsername)" "White"
            
            # Check VM network interfaces
            $networkProfile = $vm.networkProfile.networkInterfaces
            if ($networkProfile) {
                Write-ColorOutput "   🌐 Network Interfaces: $($networkProfile.Count)" "White"
            }
        }
        
        return $vm.location
    }
    return $null
}

function Test-StorageModule {
    param([string]$ExpectedLocation)
    
    Write-ColorOutput "💾 Validating Storage Account module..." "Cyan"
    
    try {
        $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($sa in $storageAccounts) {
            Write-ColorOutput "   ✅ Storage Account: $($sa.name)" "Green"
            Write-ColorOutput "   📊 Status: $($sa.statusOfPrimary)" "White"
            Write-ColorOutput "   🔐 Access Tier: $($sa.accessTier)" "White"
            Write-ColorOutput "   📍 Location: $($sa.primaryLocation)" "White"
            
            # Validate same-region deployment
            if ($ExpectedLocation -and ($sa.primaryLocation -eq $ExpectedLocation)) {
                Write-ColorOutput "   ✅ Same-region validation: SUCCESS" "Green"
            } elseif ($ExpectedLocation) {
                Write-ColorOutput "   ⚠️  Same-region validation: FAILED (Expected: $ExpectedLocation, Found: $($sa.primaryLocation))" "Yellow"
            }
            
            if ($Detailed) {
                Write-ColorOutput "   🏷️  SKU: $($sa.sku.name)" "White"
                Write-ColorOutput "   🔄 Replication: $($sa.sku.tier)" "White"
                Write-ColorOutput "   🌐 Kind: $($sa.kind)" "White"
                
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

function Test-SameRegionDeployment {
    param([object]$ResourceGroup)
    
    Write-ColorOutput "📍 Validating same-region deployment..." "Cyan"
    
    $rgLocation = $ResourceGroup.location
    Write-ColorOutput "   🏠 Resource Group Location: $rgLocation" "White"
    
    # Get all resources and check their locations
    $allResources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    
    $locationValidation = @{}
    $nonCompliantResources = @()
    
    foreach ($resource in $allResources) {
        if ($resource.location) {
            if ($locationValidation.ContainsKey($resource.location)) {
                $locationValidation[$resource.location]++
            } else {
                $locationValidation[$resource.location] = 1
            }
            
            if ($resource.location -ne $rgLocation) {
                $nonCompliantResources += $resource
            }
        }
    }
    
    # Show location distribution
    if ($Detailed) {
        Write-ColorOutput "   📊 Location Distribution:" "White"
        foreach ($location in $locationValidation.GetEnumerator()) {
            $status = if ($location.Key -eq $rgLocation) { "✅" } else { "⚠️ " }
            Write-ColorOutput "     $status $($location.Key): $($location.Value) resources" "White"
        }
    }
    
    # Validate same-region compliance
    if ($nonCompliantResources.Count -eq 0) {
        Write-ColorOutput "   ✅ Same-region compliance: 100%" "Green"
        Write-ColorOutput "   🚀 Optimal performance configuration" "Green"
    } else {
        Write-ColorOutput "   ⚠️  Same-region compliance: $([math]::Round((($allResources.Count - $nonCompliantResources.Count) / $allResources.Count) * 100, 1))%" "Yellow"
        Write-ColorOutput "   ⚠️  Non-compliant resources: $($nonCompliantResources.Count)" "Yellow"
        
        if ($Detailed) {
            foreach ($resource in $nonCompliantResources) {
                Write-ColorOutput "     - $($resource.name) in $($resource.location)" "Yellow"
            }
        }
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
            Write-ColorOutput "   📍 Location: $($vnet.location)" "White"
            
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
            Write-ColorOutput "   📍 Location: $($pip.location)" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   🏷️  SKU: $($pip.sku.name)" "White"
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
    Write-ColorOutput "📍 Same-Region Benefits: Low latency, optimal performance" "Green"
}

# Main script
Write-ColorOutput "✅ VM and Storage Same Region (Modular) Validation" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

$resourceGroup = Test-ResourceGroupExists
if (-not $resourceGroup) { exit 1 }

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VALIDATING: MODULAR VM AND STORAGE SAME REGION" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

$deploymentInfo = Get-DeploymentInfo
$validationResults = Test-ModularResources

Write-ColorOutput "" "White"
$vmLocation = Test-VMModule
Write-ColorOutput "" "White"
Test-StorageModule -ExpectedLocation $vmLocation
Write-ColorOutput "" "White"
Test-SameRegionDeployment -ResourceGroup $resourceGroup
Write-ColorOutput "" "White"
Test-NetworkConnectivity

Write-ColorOutput "" "White"
Show-ValidationSummary -Results $validationResults

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Validation completed!" "Green"
Write-ColorOutput "💡 Use -Detailed for more comprehensive information" "Cyan"
Write-ColorOutput "💡 Use -SkipConnectivityTests to skip network tests" "Cyan"
Write-ColorOutput "📍 Same-region deployment provides optimal performance" "Green"