#!/usr/bin/env pwsh

<#
.SYNOPSIS
Cleanup Azure Virtual WAN Inter-Hub Traffic Inspection Lab Resources

.DESCRIPTION
This script helps clean up the Virtual WAN lab resources. It can delete the entire
resource group or specific resource types to help manage costs during testing.

.PARAMETER ResourceGroupName
Name of the resource group containing lab resources
Default: rg-vwan-interhub-lab

.PARAMETER DeleteResourceGroup
Delete the entire resource group (fastest cleanup)

.PARAMETER StopVMsOnly
Only stop/deallocate VMs to save compute costs

.PARAMETER DeleteFirewalls
Delete Azure Firewalls only (highest cost components)

.PARAMETER Force
Skip confirmation prompts

.PARAMETER WhatIf
Show what would be deleted without actually deleting

.EXAMPLE
./cleanup.ps1 -DeleteResourceGroup

.EXAMPLE
./cleanup.ps1 -StopVMsOnly

.EXAMPLE
./cleanup.ps1 -DeleteFirewalls -Force

.EXAMPLE
./cleanup.ps1 -ResourceGroupName "my-lab-rg" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vwan-interhub-lab",
    
    [Parameter(Mandatory=$false)]
    [switch]$DeleteResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$StopVMsOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeleteFirewalls,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [System.ConsoleColor]::Red
        "Green" = [System.ConsoleColor]::Green
        "Yellow" = [System.ConsoleColor]::Yellow
        "Blue" = [System.ConsoleColor]::Blue
        "Cyan" = [System.ConsoleColor]::Cyan
        "White" = [System.ConsoleColor]::White
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-ResourceGroupExists {
    param([string]$RgName)
    
    try {
        $rg = az group show --name $RgName --output json 2>$null | ConvertFrom-Json
        return $true
    }
    catch {
        return $false
    }
}

function Get-UserConfirmation {
    param([string]$Message)
    
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput $Message "Yellow"
    $response = Read-Host "Continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

function Stop-LabVMs {
    param([string]$RgName)
    
    Write-ColorOutput "🔍 Finding VMs in resource group: $RgName" "Yellow"
    
    try {
        $vms = az vm list --resource-group $RgName --query "[].{name:name, powerState:powerState}" --output json | ConvertFrom-Json
        
        if ($vms.Count -eq 0) {
            Write-ColorOutput "ℹ️  No VMs found in resource group" "Blue"
            return
        }
        
        foreach ($vm in $vms) {
            if ($WhatIf) {
                Write-ColorOutput "Would stop VM: $($vm.name)" "Cyan"
            } else {
                Write-ColorOutput "⏹️  Stopping VM: $($vm.name)" "Yellow"
                az vm deallocate --resource-group $RgName --name $vm.name --no-wait --output none
            }
        }
        
        if (-not $WhatIf) {
            Write-ColorOutput "✅ VM stop commands initiated" "Green"
            Write-ColorOutput "💡 VMs are stopping in the background. This may take a few minutes." "Blue"
        }
    }
    catch {
        Write-ColorOutput "❌ Error stopping VMs: $($_.Exception.Message)" "Red"
    }
}

function Remove-LabFirewalls {
    param([string]$RgName)
    
    Write-ColorOutput "🔍 Finding Azure Firewalls in resource group: $RgName" "Yellow"
    
    try {
        $firewalls = az network firewall list --resource-group $RgName --query "[].{name:name, id:id}" --output json | ConvertFrom-Json
        
        if ($firewalls.Count -eq 0) {
            Write-ColorOutput "ℹ️  No Azure Firewalls found in resource group" "Blue"
            return
        }
        
        foreach ($firewall in $firewalls) {
            if ($WhatIf) {
                Write-ColorOutput "Would delete Azure Firewall: $($firewall.name)" "Cyan"
            } else {
                Write-ColorOutput "🛡️  Deleting Azure Firewall: $($firewall.name)" "Yellow"
                az network firewall delete --name $firewall.name --resource-group $RgName --output none
            }
        }
        
        if (-not $WhatIf) {
            Write-ColorOutput "✅ Azure Firewalls deleted" "Green"
            Write-ColorOutput "💰 This will significantly reduce lab costs" "Green"
        }
    }
    catch {
        Write-ColorOutput "❌ Error deleting Azure Firewalls: $($_.Exception.Message)" "Red"
    }
}

function Remove-ResourceGroup {
    param([string]$RgName)
    
    if ($WhatIf) {
        Write-ColorOutput "Would delete entire resource group: $RgName" "Cyan"
        Write-ColorOutput "This would remove ALL resources in the resource group" "Cyan"
        return
    }
    
    Write-ColorOutput "🗑️  Deleting resource group: $RgName" "Yellow"
    Write-ColorOutput "⚠️  This will delete ALL resources in the resource group!" "Red"
    
    if (Get-UserConfirmation "Are you SURE you want to delete the entire resource group?") {
        try {
            az group delete --name $RgName --yes --no-wait --output none
            Write-ColorOutput "✅ Resource group deletion initiated" "Green"
            Write-ColorOutput "💡 Deletion is running in the background. This may take 15-30 minutes." "Blue"
            Write-ColorOutput "💡 You can check progress in the Azure portal." "Blue"
        }
        catch {
            Write-ColorOutput "❌ Error deleting resource group: $($_.Exception.Message)" "Red"
        }
    } else {
        Write-ColorOutput "❌ Resource group deletion cancelled" "Yellow"
    }
}

function Show-CostInfo {
    Write-ColorOutput "`n💰 LAB COST INFORMATION" "Cyan"
    Write-ColorOutput "=======================" "Cyan"
    Write-ColorOutput "Approximate hourly costs (USD):" "White"
    Write-ColorOutput "• Virtual WAN Hub: ~$0.25/hour each (2 hubs = $0.50/hour)" "White"
    Write-ColorOutput "• Azure Firewall Standard: ~$1.25/hour each (2 firewalls = $2.50/hour)" "White"
    Write-ColorOutput "• Standard_B2s VMs: ~$0.05/hour each (2 VMs = $0.10/hour)" "White"
    Write-ColorOutput "• Storage & Networking: ~$0.01/hour" "White"
    Write-ColorOutput "`nTotal: ~$3.11/hour (~$2,240/month if left running)" "Yellow"
    Write-ColorOutput "`n💡 Cost Saving Options:" "Green"
    Write-ColorOutput "• Stop VMs only: Saves ~$0.10/hour" "Green"
    Write-ColorOutput "• Delete Firewalls: Saves ~$2.50/hour" "Green"
    Write-ColorOutput "• Delete everything: Saves ~$3.11/hour" "Green"
}

function Show-Summary {
    param([string]$RgName)
    
    Write-ColorOutput "`n📋 RESOURCE SUMMARY" "Cyan"
    Write-ColorOutput "==================" "Cyan"
    
    try {
        # VMs
        $vms = az vm list --resource-group $RgName --query "[].{name:name, location:location, vmSize:hardwareProfile.vmSize, powerState:powerState}" --output json | ConvertFrom-Json
        if ($vms.Count -gt 0) {
            Write-ColorOutput "`n🖥️  Virtual Machines ($($vms.Count)):" "Yellow"
            foreach ($vm in $vms) {
                $powerState = if ($vm.powerState) { $vm.powerState } else { "Unknown" }
                Write-ColorOutput "• $($vm.name) ($($vm.vmSize)) - $powerState" "White"
            }
        }
        
        # Firewalls
        $firewalls = az network firewall list --resource-group $RgName --query "[].{name:name, location:location}" --output json | ConvertFrom-Json
        if ($firewalls.Count -gt 0) {
            Write-ColorOutput "`n🛡️  Azure Firewalls ($($firewalls.Count)):" "Yellow"
            foreach ($fw in $firewalls) {
                Write-ColorOutput "• $($fw.name) ($($fw.location))" "White"
            }
        }
        
        # Virtual Hubs
        $hubs = az network vhub list --resource-group $RgName --query "[].{name:name, location:location}" --output json | ConvertFrom-Json
        if ($hubs.Count -gt 0) {
            Write-ColorOutput "`n🌐 Virtual Hubs ($($hubs.Count)):" "Yellow"
            foreach ($hub in $hubs) {
                Write-ColorOutput "• $($hub.name) ($($hub.location))" "White"
            }
        }
        
        # Virtual WANs
        $vwans = az network vwan list --resource-group $RgName --query "[].{name:name, location:location}" --output json | ConvertFrom-Json
        if ($vwans.Count -gt 0) {
            Write-ColorOutput "`n📡 Virtual WANs ($($vwans.Count)):" "Yellow"
            foreach ($vwan in $vwans) {
                Write-ColorOutput "• $($vwan.name) ($($vwan.location))" "White"
            }
        }
        
    }
    catch {
        Write-ColorOutput "❌ Error retrieving resource summary: $($_.Exception.Message)" "Red"
    }
}

# Main script execution
try {
    Write-ColorOutput "🧹 Azure Virtual WAN Lab - Resource Cleanup" "Cyan"
    Write-ColorOutput "===========================================" "Cyan"
    
    # Check prerequisites
    try {
        az version --output none
        $account = az account show --output json | ConvertFrom-Json
        Write-ColorOutput "✅ Connected to Azure: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Subscription: $($account.name)" "Green"
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not available or not logged in" "Red"
        Write-ColorOutput "Please run 'az login' first" "Red"
        exit 1
    }
    
    # Check if resource group exists
    if (-not (Test-ResourceGroupExists $ResourceGroupName)) {
        Write-ColorOutput "❌ Resource group '$ResourceGroupName' not found" "Red"
        Write-ColorOutput "💡 The lab may already be cleaned up or was deployed to a different resource group" "Yellow"
        exit 0
    }
    
    Write-ColorOutput "✅ Found resource group: $ResourceGroupName" "Green"
    
    # Show current resources
    Show-Summary $ResourceGroupName
    
    # Show cost information
    Show-CostInfo
    
    # Perform requested action
    if ($DeleteResourceGroup) {
        Write-ColorOutput "`n🗑️  FULL CLEANUP - DELETE RESOURCE GROUP" "Red"
        Write-ColorOutput "=======================================" "Red"
        Remove-ResourceGroup $ResourceGroupName
    }
    elseif ($StopVMsOnly) {
        Write-ColorOutput "`n⏹️  STOP VMS ONLY" "Yellow"
        Write-ColorOutput "===============" "Yellow"
        if (Get-UserConfirmation "Stop all VMs in the resource group?") {
            Stop-LabVMs $ResourceGroupName
        }
    }
    elseif ($DeleteFirewalls) {
        Write-ColorOutput "`n🛡️  DELETE AZURE FIREWALLS" "Red"
        Write-ColorOutput "========================" "Red"
        if (Get-UserConfirmation "Delete Azure Firewalls (highest cost components)?") {
            Remove-LabFirewalls $ResourceGroupName
        }
    }
    else {
        Write-ColorOutput "`n🤔 No cleanup action specified. Available options:" "Yellow"
        Write-ColorOutput "• -DeleteResourceGroup : Delete everything (recommended)" "White"
        Write-ColorOutput "• -StopVMsOnly : Just stop VMs to save compute costs" "White"
        Write-ColorOutput "• -DeleteFirewalls : Delete expensive firewall components" "White"
        Write-ColorOutput "• -WhatIf : Preview what would be deleted" "White"
        Write-ColorOutput "`nExample: ./cleanup.ps1 -DeleteResourceGroup" "Green"
    }
    
    Write-ColorOutput "`n✅ Cleanup script completed" "Green"
}
catch {
    Write-ColorOutput "❌ Cleanup script failed: $($_.Exception.Message)" "Red"
    exit 1
}