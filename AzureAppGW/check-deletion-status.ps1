#Requires -Version 7.0

<#
.SYNOPSIS
    Check the status of Azure resource deletion operations

.DESCRIPTION
    This script monitors the progress of Azure resource group and resource deletions.
    It provides real-time status updates and can monitor multiple resource groups.

.PARAMETER ResourceGroupName
    Name of the resource group to check (default: rg-appgw-lab)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current subscription if not specified)

.PARAMETER Watch
    Continuously monitor the deletion status with automatic refresh

.PARAMETER RefreshInterval
    Refresh interval in seconds when using Watch mode (default: 30)

.PARAMETER ShowDetails
    Show detailed information about remaining resources

.EXAMPLE
    .\check-deletion-status.ps1

.EXAMPLE
    .\check-deletion-status.ps1 -ResourceGroupName "my-rg" -Watch

.EXAMPLE
    .\check-deletion-status.ps1 -ShowDetails
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-appgw-lab",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Watch,
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Magenta" = "Magenta"
        "Cyan" = "Cyan"
        "White" = "White"
        "Gray" = "Gray"
    }
    
    if ($colorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $Message
    }
}

function Test-Prerequisites {
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Azure CLI is not installed or not accessible" "Red"
            Write-ColorOutput "   Please install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "Yellow"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Azure CLI is not installed or not accessible" "Red"
        return $false
    }
    
    # Check if logged in to Azure
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if (-not $account) {
            Write-ColorOutput "❌ Not logged in to Azure CLI" "Red"
            Write-ColorOutput "   Please run: az login" "Yellow"
            return $false
        }
        Write-ColorOutput "✅ Azure CLI authenticated as: $($account.user.name)" "Green"
    } catch {
        Write-ColorOutput "❌ Not logged in to Azure CLI" "Red"
        Write-ColorOutput "   Please run: az login" "Yellow"
        return $false
    }
    
    return $true
}

function Get-ResourceGroupStatus {
    Write-ColorOutput "🔍 Checking Resource Group: $ResourceGroupName" "Cyan"
    Write-ColorOutput "=" * 50 "Cyan"
    
    # Check if resource group exists
    $rgExists = az group exists --name $ResourceGroupName --output tsv 2>$null
    
    if ($rgExists -eq "false") {
        Write-ColorOutput "✅ Resource group '$ResourceGroupName' has been completely deleted" "Green"
        return @{
            Exists = $false
            State = "Deleted"
            ResourceCount = 0
            Resources = @()
        }
    }
    
    # Get resource group details
    try {
        $rgInfo = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
        $state = $rgInfo.properties.provisioningState
        
        Write-ColorOutput "📊 Resource Group Status: $state" $(if ($state -eq "Deleting") { "Yellow" } elseif ($state -eq "Succeeded") { "Green" } else { "Red" })
        Write-ColorOutput "📍 Location: $($rgInfo.location)" "White"
        Write-ColorOutput "🏷️  Tags: $(if ($rgInfo.tags) { ($rgInfo.tags | ConvertTo-Json -Compress) } else { "None" })" "White"
        
        # Get resources in the group
        $resources = az resource list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
        $resourceCount = if ($resources) { $resources.Count } else { 0 }
        
        Write-ColorOutput "📈 Resource Count: $resourceCount" "White"
        
        return @{
            Exists = $true
            State = $state
            ResourceCount = $resourceCount
            Resources = $resources
            Location = $rgInfo.location
            Tags = $rgInfo.tags
        }
    } catch {
        Write-ColorOutput "❌ Error retrieving resource group information" "Red"
        return @{
            Exists = $null
            State = "Error"
            ResourceCount = 0
            Resources = @()
        }
    }
}

function Show-ResourceDetails {
    param($resources)
    
    if ($resources -and $resources.Count -gt 0) {
        Write-ColorOutput "" "White"
        Write-ColorOutput "📋 Remaining Resources:" "Cyan"
        Write-ColorOutput "-" * 30 "Cyan"
        
        $groupedResources = $resources | Group-Object -Property type
        foreach ($group in $groupedResources) {
            Write-ColorOutput "🔹 $($group.Name) ($($group.Count))" "Yellow"
            foreach ($resource in $group.Group) {
                $status = "Unknown"
                try {
                    $resourceInfo = az resource show --ids $resource.id --query "properties.provisioningState" --output tsv 2>$null
                    if ($resourceInfo) {
                        $status = $resourceInfo
                    }
                } catch {
                    # If we can't get the status, it might be in the process of being deleted
                    $status = "Deleting"
                }
                
                $statusColor = switch ($status) {
                    "Deleting" { "Yellow" }
                    "Succeeded" { "Green" }
                    "Failed" { "Red" }
                    default { "White" }
                }
                
                Write-ColorOutput "   • $($resource.name) [$status]" $statusColor
            }
        }
    }
}

function Get-ActivityLogStatus {
    Write-ColorOutput "" "White"
    Write-ColorOutput "📊 Recent Activity Log (Last 1 hour):" "Cyan"
    Write-ColorOutput "-" * 40 "Cyan"
    
    try {
        $startTime = (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $activities = az monitor activity-log list --resource-group $ResourceGroupName --start-time $startTime --output json 2>$null | ConvertFrom-Json
        
        if ($activities -and $activities.Count -gt 0) {
            $deleteActivities = $activities | Where-Object { 
                $_.operationName.value -like "*delete*" -or 
                $_.operationName.localizedValue -like "*delete*" 
            } | Sort-Object eventTimestamp -Descending | Select-Object -First 10
            
            if ($deleteActivities -and $deleteActivities.Count -gt 0) {
                foreach ($activity in $deleteActivities) {
                    $timestamp = [DateTime]::Parse($activity.eventTimestamp).ToString("HH:mm:ss")
                    $status = $activity.status.value
                    $operation = $activity.operationName.localizedValue
                    $resource = if ($activity.resourceId) { Split-Path $activity.resourceId -Leaf } else { "Resource Group" }
                    
                    $statusColor = switch ($status) {
                        "Started" { "Yellow" }
                        "Succeeded" { "Green" }
                        "Failed" { "Red" }
                        default { "White" }
                    }
                    
                    Write-ColorOutput "⏰ $timestamp | $operation | $resource | $status" $statusColor
                }
            } else {
                Write-ColorOutput "ℹ️  No recent deletion activities found" "Gray"
            }
        } else {
            Write-ColorOutput "ℹ️  No activity log entries found" "Gray"
        }
    } catch {
        Write-ColorOutput "⚠️  Unable to retrieve activity log" "Yellow"
    }
}

function Show-DeletionProgress {
    $status = Get-ResourceGroupStatus
    
    if ($ShowDetails -and $status.Resources -and $status.Resources.Count -gt 0) {
        Show-ResourceDetails -resources $status.Resources
    }
    
    # Show activity log if resource group still exists
    if ($status.Exists -eq $true) {
        Get-ActivityLogStatus
    }
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "⏰ Last checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
    
    return $status
}

function Start-WatchMode {
    Write-ColorOutput "👁️  Starting watch mode (refresh every $RefreshInterval seconds)" "Cyan"
    Write-ColorOutput "   Press Ctrl+C to stop monitoring" "Gray"
    Write-ColorOutput "" "White"
    
    do {
        Clear-Host
        Write-ColorOutput "🔄 Azure Deletion Status Monitor" "Magenta"
        Write-ColorOutput "================================" "Magenta"
        Write-ColorOutput "" "White"
        
        $status = Show-DeletionProgress
        
        if ($status.Exists -eq $false) {
            Write-ColorOutput "" "White"
            Write-ColorOutput "🎉 Deletion completed! Resource group no longer exists." "Green"
            break
        }
        
        Write-ColorOutput "" "White"
        Write-ColorOutput "⏳ Waiting $RefreshInterval seconds before next check..." "Gray"
        
        try {
            Start-Sleep -Seconds $RefreshInterval
        } catch {
            Write-ColorOutput "" "White"
            Write-ColorOutput "👋 Monitoring stopped by user" "Yellow"
            break
        }
    } while ($true)
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔍 Azure Deletion Status Checker" "Magenta"
Write-ColorOutput "================================" "Magenta"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
    az account set --subscription $SubscriptionId
    Write-ColorOutput "" "White"
}

if ($Watch) {
    Start-WatchMode
} else {
    $status = Show-DeletionProgress
    Write-ColorOutput "" "White"
    
    if ($status.Exists -eq $false) {
        Write-ColorOutput "🎉 Status Check Complete - Resource group has been deleted!" "Green"
    } elseif ($status.State -eq "Deleting") {
        Write-ColorOutput "⏳ Status Check Complete - Deletion in progress..." "Yellow"
        Write-ColorOutput "   Run with -Watch to monitor continuously" "Cyan"
    } else {
        Write-ColorOutput "ℹ️  Status Check Complete - Resource group state: $($status.State)" "White"
    }
}