# ============================================================================
# Azure Resource Group Cleanup Script
# ============================================================================
# This script deletes all resources in the specified resource group
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
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

# ============================================================================
# Main Script
# ============================================================================
Write-Log "========================================" "INFO"
Write-Log "Azure Resource Group Cleanup" "INFO"
Write-Log "========================================" "INFO"

# Check Azure login
Test-AzureLogin

# Check if resource group exists
Write-Log "Checking resource group: $ResourceGroupName" "INFO"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Log "Resource group '$ResourceGroupName' does not exist. Nothing to clean up." "WARNING"
    exit 0
}

# List resources in the resource group
Write-Log "Resources in resource group:" "INFO"
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
if ($resources) {
    foreach ($resource in $resources) {
        Write-Log "  - $($resource.ResourceType): $($resource.Name)" "INFO"
    }
    Write-Log "Total resources: $($resources.Count)" "INFO"
}
else {
    Write-Log "  No resources found" "INFO"
}

# Confirm deletion
if (-not $Force) {
    Write-Log "" "INFO"
    Write-Log "WARNING: This will delete ALL resources in the resource group!" "WARNING"
    Write-Log "Resource Group: $ResourceGroupName" "WARNING"
    Write-Log "Location: $($rg.Location)" "WARNING"
    Write-Log "" "INFO"
    
    $confirmation = Read-Host "Are you sure you want to delete this resource group? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Log "Cleanup cancelled by user." "INFO"
        exit 0
    }
}

# Delete resource group
Write-Log "Deleting resource group: $ResourceGroupName" "INFO"
Write-Log "This may take several minutes..." "INFO"

try {
    $startTime = Get-Date
    Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob | Out-Null
    
    # Monitor deletion progress
    $jobComplete = $false
    while (-not $jobComplete) {
        Start-Sleep -Seconds 30
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            $jobComplete = $true
        }
        else {
            $elapsed = (Get-Date) - $startTime
            Write-Log "Still deleting... ($([math]::Round($elapsed.TotalMinutes, 1)) minutes elapsed)" "INFO"
        }
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Log "========================================" "SUCCESS"
    Write-Log "Cleanup completed successfully!" "SUCCESS"
    Write-Log "Duration: $($duration.Minutes)m $($duration.Seconds)s" "SUCCESS"
    Write-Log "========================================" "SUCCESS"
    
    # Clean up local files
    $outputFile = Join-Path $PSScriptRoot "deployment-outputs.json"
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
        Write-Log "Removed local deployment outputs file" "INFO"
    }
}
catch {
    Write-Log "Error during cleanup: $_" "ERROR"
    exit 1
}
