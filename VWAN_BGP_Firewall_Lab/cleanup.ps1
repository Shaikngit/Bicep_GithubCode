# ============================================================================
# VWAN BGP Lab - Cleanup Script
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-vwan-bgp-lab"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VWAN BGP Lab Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if logged in to Azure
Write-Host "`nChecking Azure login status..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged in to Azure. Please login..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "`nResource group '$ResourceGroupName' does not exist." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nResource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $($rg.Location)" -ForegroundColor Yellow

# List resources to be deleted
Write-Host "`nResources to be deleted:" -ForegroundColor Yellow
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
$resources | Format-Table Name, ResourceType -AutoSize

# Confirm deletion
$confirm = Read-Host "`nAre you sure you want to delete all resources in '$ResourceGroupName'? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "`nCleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nDeleting resource group '$ResourceGroupName'..." -ForegroundColor Yellow
Write-Host "This may take 15-30 minutes due to VPN Gateway and Virtual Hub deletion times." -ForegroundColor Yellow

$startTime = Get-Date

try {
    Remove-AzResourceGroup -Name $ResourceGroupName -Force
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
    Write-Host "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    
} catch {
    Write-Host "`n============================================" -ForegroundColor Red
    Write-Host "Cleanup failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    throw
}
