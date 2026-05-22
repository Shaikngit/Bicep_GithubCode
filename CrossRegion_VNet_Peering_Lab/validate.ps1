#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "main.bicep",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-crossregion-vnet-peering-lab-validate",

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

$allPassed = $true
$tempBuildDir = Join-Path $PSScriptRoot "temp"
$compiledFile = Join-Path $tempBuildDir "main.json"

Write-ColorOutput "=== Cross-Region VNet Peering Lab Validation ===" "Cyan"

# 1) Bicep syntax build
Write-ColorOutput "🔍 Validating Bicep syntax..." "Cyan"
if (-not (Test-Path $tempBuildDir)) {
    New-Item -Path $tempBuildDir -ItemType Directory -Force | Out-Null
}

az bicep build --file $TemplateFile --outdir $tempBuildDir 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Bicep build failed." "Red"
    $allPassed = $false
}
else {
    Write-ColorOutput "✅ Bicep syntax validation passed." "Green"
}

# 2) ARM validation against temporary RG
Write-ColorOutput "🔍 Validating ARM template deployment..." "Cyan"
az group create --name $ResourceGroupName --location $Location --output none
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Failed to create validation resource group." "Red"
    $allPassed = $false
}
else {
    $validateArgs = @(
        'deployment', 'group', 'validate',
        '--resource-group', $ResourceGroupName,
        '--template-file', $TemplateFile,
        '--parameters', 'adminUsername=azureuser',
        '--parameters', 'adminPasswordOrKey=P@ssw0rd1234!',
        '--parameters', 'authenticationType=password'
    )

    if ($Detailed) {
        az @validateArgs
    }
    else {
        az @validateArgs --output none
    }

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ ARM validation failed." "Red"
        $allPassed = $false
    }
    else {
        Write-ColorOutput "✅ ARM validation passed." "Green"
    }

    az group delete --name $ResourceGroupName --yes --no-wait --output none 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Validation resource group deletion initiated." "Green"
    }
    else {
        Write-ColorOutput "⚠️  Could not delete validation resource group automatically." "Yellow"
    }
}

# Cleanup local temp build artifacts
if (Test-Path $compiledFile) {
    Remove-Item -Path $compiledFile -Force -ErrorAction SilentlyContinue
}
if (Test-Path $tempBuildDir) {
    Remove-Item -Path $tempBuildDir -Force -Recurse -ErrorAction SilentlyContinue
}

if ($allPassed) {
    Write-ColorOutput "🎉 All validation tests passed!" "Green"
    exit 0
}

Write-ColorOutput "❌ Some validation tests failed." "Red"
exit 1
