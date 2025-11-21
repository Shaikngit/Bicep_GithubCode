#Requires -Version 7.0

<#
.SYNOPSIS
    Cleanup script for Private Endpoint Policies Lab (Modular)

.DESCRIPTION
    This script safely removes all resources from the Private Endpoint Policies Lab deployment,
    including client VM, firewall, SQL server, VNet peering, and associated resources.

.PARAMETER ResourceGroupName
    Name of the resource group to clean up (default: rg-pe-policies-lab)

.PARAMETER Force
    Skip confirmation prompts and force cleanup

.PARAMETER PreserveResourceGroup
    Keep the resource group after cleaning up all resources

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName "rg-pe-policies-lab" -Force
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-policies-lab",
    
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
    
    $firewalls = $Resources | Where-Object { $_.type -eq "Microsoft.Network/azureFirewalls" }
    $sqlServers = $Resources | Where-Object { $_.type -like "*Sql*" }
    $vms = $Resources | Where-Object { $_.type -eq "Microsoft.Compute/virtualMachines" }
    $privateEndpoints = $Resources | Where-Object { $_.type -eq "Microsoft.Network/privateEndpoints" }
    $vnets = $Resources | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" }
    
    if ($firewalls.Count -gt 0) { Write-ColorOutput "   • Azure Firewall: ~$912/month" "Green" }
    if ($sqlServers.Count -gt 0) { Write-ColorOutput "   • SQL Database: ~$150-300/month" "Green" }
    if ($vms.Count -gt 0) { Write-ColorOutput "   • VMs ($($vms.Count)): ~$($vms.Count * 35)/month" "Green" }
    if ($privateEndpoints.Count -gt 0) { Write-ColorOutput "   • Private Endpoints ($($privateEndpoints.Count)): ~$($privateEndpoints.Count * 7)/month" "Green" }
    if ($vnets.Count -gt 0) { Write-ColorOutput "   • VNets: ~$10/month" "Green" }
    Write-ColorOutput "   💸 Total estimated savings: ~$1200+/month" "Green"
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
    Write-ColorOutput "⚠️  This includes VMs, databases, networking, and all associated data!" "Red"
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
    Write-ColorOutput "⏱️  This may take 15-30 minutes for complete cleanup..." "Yellow"
    
    # Step 1: Delete specific high-dependency resources first
    Write-ColorOutput "🔥 Cleaning up Azure Firewall..." "Cyan"
    $firewalls = $Resources | Where-Object { $_.type -eq "Microsoft.Network/azureFirewalls" }
    foreach ($fw in $firewalls) {
        Write-ColorOutput "   • Deleting firewall: $($fw.name)" "White"
        az network firewall delete --name $fw.name --resource-group $ResourceGroupName --output none 2>$null
    }
    
    Write-ColorOutput "🗄️  Cleaning up SQL resources..." "Cyan"
    $sqlResources = $Resources | Where-Object { $_.type -like "*Sql*" }
    foreach ($sql in $sqlResources) {
        Write-ColorOutput "   • Deleting SQL resource: $($sql.name)" "White"
        az resource delete --resource-group $ResourceGroupName --name $sql.name --resource-type $sql.type --output none 2>$null
    }
    
    Write-ColorOutput "💻 Cleaning up virtual machines..." "Cyan"
    $vms = $Resources | Where-Object { $_.type -eq "Microsoft.Compute/virtualMachines" }
    foreach ($vm in $vms) {
        Write-ColorOutput "   • Deleting VM: $($vm.name)" "White"
        az vm delete --resource-group $ResourceGroupName --name $vm.name --yes --output none 2>$null
    }
    
    # Step 2: Delete the entire resource group (most efficient for remaining resources)
    if (-not $PreserveResourceGroup) {
        Write-ColorOutput "🗑️  Deleting entire resource group (most efficient)..." "Cyan"
        az group delete --name $ResourceGroupName --yes --no-wait --output none
        
        Write-ColorOutput "✅ Cleanup initiated successfully!" "Green"
        Write-ColorOutput "🔄 Resource group deletion is running in background" "Yellow"
        Write-ColorOutput "⏱️  Complete cleanup will finish in 15-30 minutes" "Yellow"
        Write-ColorOutput "💸 Monthly cost savings: ~$1200+/month" "Green"
    } else {
        Write-ColorOutput "🗑️  Cleaning remaining resources..." "Cyan"
        Write-ColorOutput "⏱️  This will take longer than full RG deletion..." "Yellow"
        
        # Delete all remaining resources
        $otherResources = $Resources | Where-Object { $_.type -notin @("Microsoft.Network/azureFirewalls", "Microsoft.Sql/servers", "Microsoft.Compute/virtualMachines") }
        foreach ($resource in $otherResources) {
            Write-ColorOutput "   • Deleting: $($resource.name) ($($resource.type))" "White"
            az resource delete --resource-group $ResourceGroupName --name $resource.name --resource-type $resource.type --output none 2>$null
        }
        
        Write-ColorOutput "✅ Resource cleanup completed!" "Green"
        Write-ColorOutput "📦 Resource group preserved: $ResourceGroupName" "Yellow"
    }
}

# Main script
Write-ColorOutput "🧹 Private Endpoint Policies Lab (Modular) Cleanup" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

if (-not (Test-AzureConnection)) { exit 1 }

if (-not (Test-ResourceGroupExists)) {
    Write-ColorOutput "✅ Resource group already cleaned up or doesn't exist." "Green"
    exit 0
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  CLEANUP TARGET: MODULAR PRIVATE ENDPOINT POLICIES LAB" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "This will clean up all modular components:" "White"
Write-ColorOutput "• Client VM module resources" "White"
Write-ColorOutput "• Firewall module resources" "White"
Write-ColorOutput "• SQL Server module resources" "White"
Write-ColorOutput "• VNet peering and route tables" "White"
Write-ColorOutput "• Private endpoint policies" "White"
Write-ColorOutput "• All associated networking and storage" "White"
Write-ColorOutput "" "White"

$resources = Get-ResourceGroupResources
Show-ResourceSummary -Resources $resources

Write-ColorOutput "" "White"
Write-ColorOutput "📋 Cleanup Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Preserve RG: $(if($PreserveResourceGroup){'Yes'}else{'No'})" "White"
Write-ColorOutput "• Force Mode: $(if($Force){'Yes'}else{'No'})" "White"
Write-ColorOutput "=========================================================" "Cyan"

if (-not (Get-UserConfirmation -Resources $resources)) {
    Write-ColorOutput "❌ Cleanup cancelled by user." "Red"
    exit 1
}

Start-Cleanup -Resources $resources
Write-ColorOutput "🎉 Cleanup script completed!" "Green"