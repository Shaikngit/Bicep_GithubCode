#Requires -Version 7.0

<#
.SYNOPSIS
    Cleanup script for Private Endpoint with Public Load Balancer VM

.DESCRIPTION
    This script safely removes all resources from the Private Endpoint with Public Load Balancer VM deployment,
    including VMs, load balancers, private endpoints, and associated networking resources.

.PARAMETER ResourceGroupName
    Name of the resource group to clean up (default: rg-pe-plb-vm)

.PARAMETER Force
    Skip confirmation prompts and force cleanup

.PARAMETER PreserveResourceGroup
    Keep the resource group after cleaning up all resources

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName "rg-pe-plb-vm" -Force
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-plb-vm",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$PreserveResourceGroup
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
        Write-ColorOutput "📧 Subscription: $($account.name) ($($account.id))" "White"
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
            Write-ColorOutput "📍 Location: $($rg.location)" "White"
            return $true
        }
    } catch {}
    Write-ColorOutput "⚠️  Resource group not found: $ResourceGroupName" "Yellow"
    return $false
}

function Get-ResourceGroupResources {
    try {
        $resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        return $resources
    } catch {
        Write-ColorOutput "❌ Failed to list resources in $ResourceGroupName" "Red"
        return @()
    }
}

function Show-ResourceSummary {
    param([array]$Resources)
    
    if ($Resources.Count -eq 0) {
        Write-ColorOutput "📦 No resources found in resource group." "Yellow"
        return
    }
    
    Write-ColorOutput "📦 Resources to be deleted:" "Cyan"
    $resourceTypes = $Resources | Group-Object type | Sort-Object Name
    
    foreach ($type in $resourceTypes) {
        Write-ColorOutput "   • $($type.Name): $($type.Count) resource(s)" "White"
        foreach ($resource in $type.Group) {
            Write-ColorOutput "     - $($resource.name)" "White"
        }
    }
    
    # Estimate cost savings
    Write-ColorOutput "" "White"
    Write-ColorOutput "💰 Monthly cost savings estimate:" "Green"
    
    $loadBalancers = $Resources | Where-Object { $_.type -eq "Microsoft.Network/loadBalancers" }
    $vms = $Resources | Where-Object { $_.type -eq "Microsoft.Compute/virtualMachines" }
    $privateEndpoints = $Resources | Where-Object { $_.type -eq "Microsoft.Network/privateEndpoints" }
    $publicIPs = $Resources | Where-Object { $_.type -eq "Microsoft.Network/publicIPAddresses" }
    $vnets = $Resources | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" }
    
    if ($loadBalancers.Count -gt 0) { Write-ColorOutput "   • Load Balancers ($($loadBalancers.Count)): ~$($loadBalancers.Count * 20)/month" "Green" }
    if ($vms.Count -gt 0) { Write-ColorOutput "   • VMs ($($vms.Count)): ~$($vms.Count * 35)/month" "Green" }
    if ($privateEndpoints.Count -gt 0) { Write-ColorOutput "   • Private Endpoints ($($privateEndpoints.Count)): ~$($privateEndpoints.Count * 7)/month" "Green" }
    if ($publicIPs.Count -gt 0) { Write-ColorOutput "   • Public IPs ($($publicIPs.Count)): ~$($publicIPs.Count * 4)/month" "Green" }
    if ($vnets.Count -gt 0) { Write-ColorOutput "   • VNets: ~$5/month" "Green" }
    Write-ColorOutput "   💸 Total estimated savings: ~$85-95/month" "Green"
}

function Get-UserConfirmation {
    param([array]$Resources)
    
    if ($Force) {
        Write-ColorOutput "⚡ Force mode enabled - skipping confirmation" "Yellow"
        return $true
    }
    
    if ($Resources.Count -eq 0) {
        return $true
    }
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "⚠️  This action will permanently delete ALL resources in the resource group!" "Red"
    Write-ColorOutput "⚠️  This includes VMs, load balancers, private endpoints, and all associated data!" "Red"
    Write-ColorOutput "⚠️  This action cannot be undone!" "Red"
    
    $response = Read-Host "Are you sure you want to proceed? Type 'DELETE' to confirm"
    return ($response -eq "DELETE")
}

function Start-Cleanup {
    param([array]$Resources)
    
    if ($SubscriptionId) {
        Write-ColorOutput "🔄 Setting subscription context..." "Cyan"
        az account set --subscription $SubscriptionId
    }
    
    if ($Resources.Count -eq 0) {
        Write-ColorOutput "📦 No resources to clean up." "Yellow"
        return
    }
    
    Write-ColorOutput "🧹 Starting cleanup process..." "Cyan"
    Write-ColorOutput "⏱️  This may take 12-18 minutes for complete cleanup..." "Yellow"
    
    # Step 1: Delete VMs first (they take longest)
    Write-ColorOutput "💻 Cleaning up virtual machines..." "Cyan"
    $vms = $Resources | Where-Object { $_.type -eq "Microsoft.Compute/virtualMachines" }
    foreach ($vm in $vms) {
        Write-ColorOutput "   • Deleting VM: $($vm.name)" "White"
        az vm delete --resource-group $ResourceGroupName --name $vm.name --yes --output none 2>$null
    }
    
    # Step 2: Delete load balancers (may have dependencies)
    Write-ColorOutput "⚖️  Cleaning up load balancers..." "Cyan"
    $loadBalancers = $Resources | Where-Object { $_.type -eq "Microsoft.Network/loadBalancers" }
    foreach ($lb in $loadBalancers) {
        Write-ColorOutput "   • Deleting Load Balancer: $($lb.name)" "White"
        az network lb delete --resource-group $ResourceGroupName --name $lb.name --output none 2>$null
    }
    
    # Step 3: Delete private endpoints
    Write-ColorOutput "🔒 Cleaning up private endpoints..." "Cyan"
    $privateEndpoints = $Resources | Where-Object { $_.type -eq "Microsoft.Network/privateEndpoints" }
    foreach ($pe in $privateEndpoints) {
        Write-ColorOutput "   • Deleting Private Endpoint: $($pe.name)" "White"
        az network private-endpoint delete --resource-group $ResourceGroupName --name $pe.name --output none 2>$null
    }
    
    # Step 4: Delete the entire resource group (most efficient for remaining resources)
    if (-not $PreserveResourceGroup) {
        Write-ColorOutput "🗑️  Deleting entire resource group (most efficient)..." "Cyan"
        az group delete --name $ResourceGroupName --yes --no-wait --output none
        
        Write-ColorOutput "✅ Cleanup initiated successfully!" "Green"
        Write-ColorOutput "🔄 Resource group deletion is running in background" "Yellow"
        Write-ColorOutput "⏱️  Complete cleanup will finish in 12-18 minutes" "Yellow"
        Write-ColorOutput "💸 Monthly cost savings: ~$85-95/month" "Green"
    } else {
        Write-ColorOutput "🗑️  Cleaning remaining resources..." "Cyan"
        Write-ColorOutput "⏱️  This will take longer than full RG deletion..." "Yellow"
        
        # Delete all remaining resources
        $otherResources = $Resources | Where-Object { $_.type -notin @("Microsoft.Compute/virtualMachines", "Microsoft.Network/loadBalancers", "Microsoft.Network/privateEndpoints") }
        foreach ($resource in $otherResources) {
            Write-ColorOutput "   • Deleting: $($resource.name) ($($resource.type))" "White"
            az resource delete --resource-group $ResourceGroupName --name $resource.name --resource-type $resource.type --output none 2>$null
        }
        
        Write-ColorOutput "✅ Resource cleanup completed!" "Green"
        Write-ColorOutput "📦 Resource group preserved: $ResourceGroupName" "Yellow"
    }
}

# Main script
Write-ColorOutput "🧹 Private Endpoint with Public Load Balancer VM Cleanup" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

if (-not (Test-ResourceGroupExists)) {
    Write-ColorOutput "✅ Resource group already cleaned up or doesn't exist." "Green"
    exit 0
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  CLEANUP TARGET: PRIVATE ENDPOINT WITH PUBLIC LOAD BALANCER VM" "Cyan"
Write-ColorOutput "=================================================================" "Cyan"
Write-ColorOutput "This will clean up:" "White"
Write-ColorOutput "• Virtual machines with load balancer configuration" "White"
Write-ColorOutput "• Public load balancer with frontend/backend pools" "White"
Write-ColorOutput "• Private endpoints and private link services" "White"
Write-ColorOutput "• VNet and subnet configurations" "White"
Write-ColorOutput "• Public IPs and network security groups" "White"
Write-ColorOutput "• All associated networking and storage" "White"
Write-ColorOutput "" "White"

$resources = Get-ResourceGroupResources
Show-ResourceSummary -Resources $resources

Write-ColorOutput "" "White"
Write-ColorOutput "📋 Cleanup Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Preserve RG: $(if($PreserveResourceGroup){'Yes'}else{'No'})" "White"
Write-ColorOutput "• Force Mode: $(if($Force){'Yes'}else{'No'})" "White"
Write-ColorOutput "=================================================================" "Cyan"

if (-not (Get-UserConfirmation -Resources $resources)) {
    Write-ColorOutput "❌ Cleanup cancelled by user." "Red"
    exit 1
}

Start-Cleanup -Resources $resources
Write-ColorOutput "🎉 Cleanup script completed!" "Green"