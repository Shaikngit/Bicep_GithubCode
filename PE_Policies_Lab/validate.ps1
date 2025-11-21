#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for Private Endpoint Policies Lab (Modular)

.DESCRIPTION
    This script validates the Private Endpoint Policies Lab deployment by checking
    all modular components including client VM, firewall, SQL server, VNet peering,
    private endpoints, and policy configurations.

.PARAMETER ResourceGroupName
    Name of the resource group to validate (default: rg-pe-policies-lab)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER SkipConnectivityTests
    Skip network connectivity tests

.PARAMETER Detailed
    Show detailed validation information

.EXAMPLE
    .\validate.ps1 -ResourceGroupName "rg-pe-policies-lab" -Detailed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-policies-lab",
    
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
        "Microsoft.Compute/virtualMachines" = "Client VMs"
        "Microsoft.Network/azureFirewalls" = "Azure Firewall"
        "Microsoft.Sql/servers" = "SQL Server"
        "Microsoft.Network/privateEndpoints" = "Private Endpoints"
        "Microsoft.Network/virtualNetworks" = "Virtual Networks"
        "Microsoft.Network/routeTables" = "Route Tables"
        "Microsoft.Network/networkSecurityGroups" = "Network Security Groups"
        "Microsoft.Network/networkInterfaces" = "Network Interfaces"
        "Microsoft.Storage/storageAccounts" = "Storage Accounts"
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

function Test-ClientVMModule {
    Write-ColorOutput "💻 Validating Client VM module..." "Cyan"
    
    $vms = az vm list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    foreach ($vm in $vms | Where-Object { $_.name -like "*client*" -or $_.name -like "*vm*" }) {
        $vmStatus = az vm get-instance-view --resource-group $ResourceGroupName --name $vm.name --output json | ConvertFrom-Json
        $powerState = ($vmStatus.instanceView.statuses | Where-Object { $_.code -like "PowerState/*" }).displayStatus
        
        Write-ColorOutput "   ✅ VM: $($vm.name)" "Green"
        Write-ColorOutput "   🔋 Power State: $powerState" "White"
        Write-ColorOutput "   💾 VM Size: $($vm.hardwareProfile.vmSize)" "White"
        
        if ($Detailed) {
            Write-ColorOutput "   📍 Location: $($vm.location)" "White"
            Write-ColorOutput "   🖥️  OS Type: $($vm.storageProfile.osDisk.osType)" "White"
        }
    }
}

function Test-FirewallModule {
    Write-ColorOutput "🔥 Validating Firewall module..." "Cyan"
    
    try {
        $firewalls = az network firewall list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($fw in $firewalls) {
            Write-ColorOutput "   ✅ Firewall: $($fw.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($fw.provisioningState)" "White"
            Write-ColorOutput "   🛡️  Threat Intel Mode: $($fw.threatIntelMode)" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   🏷️  SKU Tier: $($fw.sku.tier)" "White"
                Write-ColorOutput "   📍 Zones: $($fw.zones -join ', ')" "White"
                
                # Check firewall policies
                if ($fw.firewallPolicy) {
                    Write-ColorOutput "   📋 Policy: $($fw.firewallPolicy.id.Split('/')[-1])" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate firewall details" "Yellow"
    }
}

function Test-SQLModule {
    Write-ColorOutput "🗄️  Validating SQL Server module..." "Cyan"
    
    try {
        $sqlServers = az sql server list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($server in $sqlServers) {
            Write-ColorOutput "   ✅ SQL Server: $($server.name)" "Green"
            Write-ColorOutput "   📊 State: $($server.state)" "White"
            Write-ColorOutput "   🔐 Admin Login: $($server.administratorLogin)" "White"
            
            if ($Detailed) {
                Write-ColorOutput "   🌐 FQDN: $($server.fullyQualifiedDomainName)" "White"
                Write-ColorOutput "   📍 Location: $($server.location)" "White"
                
                # Check databases
                $databases = az sql db list --resource-group $ResourceGroupName --server $server.name --output json | ConvertFrom-Json
                foreach ($db in $databases | Where-Object { $_.name -ne "master" }) {
                    Write-ColorOutput "   💾 Database: $($db.name)" "White"
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate SQL server details" "Yellow"
    }
}

function Test-PrivateEndpoints {
    Write-ColorOutput "🔒 Validating Private Endpoints..." "Cyan"
    
    try {
        $privateEndpoints = az network private-endpoint list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($pe in $privateEndpoints) {
            Write-ColorOutput "   ✅ Private Endpoint: $($pe.name)" "Green"
            Write-ColorOutput "   📊 Provisioning State: $($pe.provisioningState)" "White"
            
            if ($Detailed) {
                # Check private DNS zones
                $privateDnsZones = az network private-dns zone list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
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

function Test-NetworkConnectivity {
    if ($SkipConnectivityTests) {
        Write-ColorOutput "⏭️  Skipping network connectivity tests" "Yellow"
        return
    }
    
    Write-ColorOutput "🌐 Testing network connectivity..." "Cyan"
    
    # Test VNet peering
    try {
        $vnets = az network vnet list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($vnet in $vnets) {
            $peerings = az network vnet peering list --resource-group $ResourceGroupName --vnet-name $vnet.name --output json | ConvertFrom-Json
            if ($peerings) {
                Write-ColorOutput "   ✅ VNet Peerings found for: $($vnet.name)" "Green"
                if ($Detailed) {
                    foreach ($peering in $peerings) {
                        Write-ColorOutput "     📡 $($peering.name): $($peering.peeringState)" "White"
                    }
                }
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not test VNet peering" "Yellow"
    }
    
    # Test route tables
    try {
        $routeTables = az network route-table list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        foreach ($rt in $routeTables) {
            Write-ColorOutput "   ✅ Route Table: $($rt.name)" "Green"
            if ($Detailed) {
                $routes = az network route-table route list --resource-group $ResourceGroupName --route-table-name $rt.name --output json | ConvertFrom-Json
                Write-ColorOutput "     🗺️  Routes: $($routes.Count)" "White"
            }
        }
    } catch {
        Write-ColorOutput "   ⚠️  Could not validate route tables" "Yellow"
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
            "Azure Firewall" { $totalCost += 912 }
            "SQL Server" { $totalCost += 200 }
            "Client VMs" { $totalCost += ($result.Count * 35) }
            "Private Endpoints" { $totalCost += ($result.Count * 7) }
            "Virtual Networks" { $totalCost += 10 }
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
Write-ColorOutput "✅ Private Endpoint Policies Lab (Modular) Validation" "Cyan"
Write-ColorOutput "======================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

if (-not (Test-ResourceGroupExists)) { exit 1 }

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VALIDATING: MODULAR PRIVATE ENDPOINT POLICIES LAB" "Cyan"
Write-ColorOutput "====================================================" "Cyan"

$deploymentInfo = Get-DeploymentInfo
$validationResults = Test-ModularResources

Write-ColorOutput "" "White"
Test-ClientVMModule
Write-ColorOutput "" "White"
Test-FirewallModule
Write-ColorOutput "" "White"
Test-SQLModule
Write-ColorOutput "" "White"
Test-PrivateEndpoints
Write-ColorOutput "" "White"
Test-NetworkConnectivity

Write-ColorOutput "" "White"
Show-ValidationSummary -Results $validationResults

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Validation completed!" "Green"
Write-ColorOutput "💡 Use -Detailed for more comprehensive information" "Cyan"
Write-ColorOutput "💡 Use -SkipConnectivityTests to skip network tests" "Cyan"