#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for VMs in same VNet Bicep template

.DESCRIPTION
    This script validates the Bicep template syntax, parameters, and deployment readiness.

.PARAMETER TemplateFile
    Path to the Bicep template file (default: main.bicep)

.PARAMETER Detailed
    Show detailed validation output

.EXAMPLE
    .\validate.ps1

.EXAMPLE
    .\validate.ps1 -Detailed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "main.bicep",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White; "Magenta" = [ConsoleColor]::Magenta }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-BicepSyntax {
    Write-ColorOutput "🔍 Validating Bicep syntax..." "Cyan"
    $buildResult = az bicep build --file $TemplateFile --outdir "temp" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Bicep syntax validation passed" "Green"
        # Cleanup
        if (Test-Path "temp") { Remove-Item "temp" -Force -Recurse -ErrorAction SilentlyContinue }
        return $true
    } else {
        Write-ColorOutput "❌ Bicep syntax validation failed:" "Red"
        Write-ColorOutput $buildResult "Red"
        return $false
    }
}

function Test-TemplateValidation {
    Write-ColorOutput "🔍 Running ARM template validation..." "Cyan"
    
    # Create temp RG
    $tempRg = "rg-vm-samevnet-validate-temp"
    az group create --name $tempRg --location "southeastasia" --output none
    
    $validateResult = az deployment group validate --resource-group $tempRg --template-file $TemplateFile --parameters adminUsername=validateuser adminPassword=ValidatePass123! allowedRdpSourceAddress=0.0.0.0/0 vmSizeOption=Non-Overlake osType=Windows 2>&1
    
    # Cleanup
    az group delete --name $tempRg --yes --no-wait --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ ARM template validation passed" "Green"
        if ($Detailed) { Write-ColorOutput $validateResult "White" }
        return $true
    } else {
        Write-ColorOutput "❌ ARM template validation failed:" "Red"
        Write-ColorOutput $validateResult "Red"
        return $false
    }
}

# Main validation
Write-ColorOutput "✅ VMs in Same VNet Template Validator" "Magenta"
Write-ColorOutput "=====================================" "Magenta"

if (-not (Test-Path $TemplateFile)) {
    Write-ColorOutput "❌ Template file not found: $TemplateFile" "Red"
    exit 1
}

$tests = @(
    @{ Name = "Bicep Syntax"; Test = { Test-BicepSyntax } },
    @{ Name = "ARM Validation"; Test = { Test-TemplateValidation } }
)

$passed = 0
foreach ($test in $tests) {
    Write-ColorOutput "▶️  $($test.Name)" "Yellow"
    if (& $test.Test) { $passed++ }
}

Write-ColorOutput "" "White"
Write-ColorOutput "📊 VALIDATION SUMMARY" "Cyan"
Write-ColorOutput "✅ Tests passed: $passed/$($tests.Count)" "Green"

if ($passed -eq $tests.Count) {
    Write-ColorOutput "🎉 All validation tests passed!" "Green"
    exit 0
} else {
    Write-ColorOutput "❌ Some validation tests failed" "Red"
    exit 1
}