#Requires -Version 7.0
<#
.SYNOPSIS
    Quick Azure login for the Bicep Lab workspace.
.DESCRIPTION
    Reads .env for subscription/tenant context, logs in via WAM broker (or device code),
    and sets the correct subscription. Run from the repo root.
.EXAMPLE
    .\login.ps1
    .\login.ps1 -DeviceCode   # Use device code flow instead of browser
#>

param(
    [switch]$DeviceCode
)

# --- Load .env ---
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "❌ .env file not found at $envFile" -ForegroundColor Red
    exit 1
}

$envVars = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.+)$') {
        $envVars[$matches[1].Trim()] = $matches[2].Trim()
    }
}

$subscriptionId   = $envVars['AZURE_SUBSCRIPTION_ID']
$subscriptionName = $envVars['AZURE_SUBSCRIPTION_NAME']
$tenantId         = $envVars['AZURE_TENANT_ID']

Write-Host ""
Write-Host "🔐 Bicep Lab — Azure Login" -ForegroundColor Cyan
Write-Host "   Subscription : $subscriptionName" -ForegroundColor White
Write-Host "   Tenant       : $tenantId" -ForegroundColor White
Write-Host ""

# --- Check if already logged in to the right subscription ---
$currentAccount = az account show --query "{id:id, tenantId:tenantId}" -o json 2>$null | ConvertFrom-Json
if ($currentAccount -and $currentAccount.id -eq $subscriptionId -and $currentAccount.tenantId -eq $tenantId) {
    Write-Host "✅ Already logged in to the correct subscription!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# --- Login ---
Write-Host "⏳ Logging in..." -ForegroundColor Yellow

if ($DeviceCode) {
    az login --tenant $tenantId --use-device-code
} else {
    az login --tenant $tenantId
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Login failed" -ForegroundColor Red
    exit 1
}

# --- Set subscription ---
az account set --subscription $subscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set subscription" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Logged in and set to: $subscriptionName ($subscriptionId)" -ForegroundColor Green
Write-Host ""
