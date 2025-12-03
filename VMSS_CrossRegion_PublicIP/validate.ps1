#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the VMSS Cross-Region Bicep template

.DESCRIPTION
    This script validates the Bicep template without deploying any resources.

.PARAMETER ResourceGroupName
    Name of the resource group to validate against (will be created temporarily if needed)

.PARAMETER AdminUsername
    Administrator username for validation

.PARAMETER AdminPassword
    Administrator password for validation

.EXAMPLE
    .\validate.ps1 -AdminUsername "azureuser" -AdminPassword "TestP@ssword123!"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vmss-crossregion-validate",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "azureuser",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword = "ValidateP@ssword123!"
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔍 VMSS Cross-Region Template Validation" "Cyan"
Write-ColorOutput "==========================================" "Cyan"

$templateFile = Join-Path $PSScriptRoot "main.bicep"
$Location = "southeastasia"

# Check if template file exists
if (-not (Test-Path $templateFile)) {
    Write-ColorOutput "❌ Template file not found: $templateFile" "Red"
    exit 1
}

Write-ColorOutput "✅ Template file found: $templateFile" "Green"

# Validate Bicep syntax
Write-ColorOutput "🔍 Validating Bicep syntax..." "Cyan"
az bicep build --file $templateFile --stdout | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Bicep syntax is valid!" "Green"
} else {
    Write-ColorOutput "❌ Bicep syntax validation failed" "Red"
    exit 1
}

# Create temporary resource group for validation
Write-ColorOutput "📦 Creating temporary resource group for validation..." "Cyan"
az group create --name $ResourceGroupName --location $Location --output none 2>$null

# Validate deployment
Write-ColorOutput "🔍 Validating deployment template..." "Cyan"

$deployParams = @(
    "adminUsername=$AdminUsername"
    "adminPassword=$AdminPassword"
    "resourcePrefix=vmss"
    "location1=southeastasia"
    "location2=eastasia"
    "instanceCount=1"
    "ubuntuOSVersion=Ubuntu-2204"
    "vmSize=Standard_D2s_v4"
)

az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $deployParams `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Deployment template validation passed!" "Green"
} else {
    Write-ColorOutput "❌ Deployment template validation failed" "Red"
}

# Clean up temporary resource group
Write-ColorOutput "🧹 Cleaning up temporary resource group..." "Cyan"
az group delete --name $ResourceGroupName --yes --no-wait 2>$null

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Validation completed!" "Green"
