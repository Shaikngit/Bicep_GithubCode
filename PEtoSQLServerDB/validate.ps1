#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for Private Endpoint to SQL Server Database Bicep template

.DESCRIPTION
    This script validates the Bicep template syntax, parameters, and deployment readiness.
    It performs comprehensive checks without deploying actual resources.

.PARAMETER TemplateFile
    Path to the Bicep template file (default: main.bicep)

.PARAMETER ParametersFile
    Path to parameters file (optional)

.PARAMETER ResourceGroupName
    Name of the resource group for validation context (default: rg-pe-sqlserverdb-validate)

.PARAMETER Location
    Azure region for validation (default: eastus)

.PARAMETER SubscriptionId
    Azure subscription ID (optional - uses current subscription if not specified)

.PARAMETER Detailed
    Show detailed validation output including resource dependencies

.EXAMPLE
    .\validate.ps1

.EXAMPLE
    .\validate.ps1 -Detailed

.EXAMPLE
    .\validate.ps1 -TemplateFile main.bicep -Location westus2
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "main.bicep",
    
    [Parameter(Mandatory=$false)]
    [string]$ParametersFile,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-pe-sqlserverdb-validate",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
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
        "Magenta" = [ConsoleColor]::Magenta
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    $allGood = $true
    
    # Test Azure CLI
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not found" "Red"
        $allGood = $false
    }
    
    # Test Azure login
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name)" "Green"
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure" "Red"
        $allGood = $false
    }
    
    # Test Bicep CLI
    try {
        $version = az bicep version
        Write-ColorOutput "✅ Bicep CLI version: $version" "Green"
    }
    catch {
        Write-ColorOutput "❌ Bicep CLI not found" "Red"
        $allGood = $false
    }
    
    return $allGood
}

function Test-FileExists {
    param([string]$FilePath, [string]$Description)
    
    if (Test-Path $FilePath) {
        Write-ColorOutput "✅ $Description found: $FilePath" "Green"
        return $true
    } else {
        Write-ColorOutput "❌ $Description not found: $FilePath" "Red"
        return $false
    }
}

function Test-BicepSyntax {
    param([string]$TemplateFile)
    
    Write-ColorOutput "🔍 Validating Bicep syntax..." "Cyan"
    
    # Build the template to check for syntax errors
    $buildResult = az bicep build --file $TemplateFile --outdir "temp" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Bicep syntax validation passed" "Green"
        # Clean up generated ARM template
        $armFile = $TemplateFile -replace '\.bicep$', '.json'
        $tempArmFile = Join-Path "temp" (Split-Path $armFile -Leaf)
        if (Test-Path $tempArmFile) {
            Remove-Item $tempArmFile -Force
        }
        if (Test-Path "temp") {
            Remove-Item "temp" -Force -Recurse -ErrorAction SilentlyContinue
        }
        return $true
    } else {
        Write-ColorOutput "❌ Bicep syntax validation failed:" "Red"
        Write-ColorOutput $buildResult "Red"
        return $false
    }
}

function Test-TemplateValidation {
    param([string]$TemplateFile, [string]$ResourceGroupName, [string]$Location)
    
    Write-ColorOutput "🔍 Running ARM template validation..." "Cyan"
    
    # Create temporary resource group for validation
    Write-ColorOutput "📦 Creating temporary validation resource group..." "Yellow"
    az group create --name $ResourceGroupName --location $Location --output none
    
    # Build validation command
    $validateCmd = @(
        "az", "deployment", "group", "validate"
        "--resource-group", $ResourceGroupName
        "--template-file", $TemplateFile
        "--parameters"
        "sqlAdministratorLogin=validationsqladmin"
        "sqlAdministratorLoginPassword=ValidationSqlPass123!"
        "vmAdminUsername=validationvmadmin"
        "vmAdminPassword=ValidationVmPass123!"
        "vmSizeOption=Non-Overlake"
    )
    
    # Add parameters file if specified
    if ($ParametersFile -and (Test-Path $ParametersFile)) {
        $validateCmd += @("--parameters", "@$ParametersFile")
    }
    
    # Execute validation
    $validationResult = & $validateCmd[0] $validateCmd[1..($validateCmd.Length-1)] 2>&1
    
    # Clean up temporary resource group
    Write-ColorOutput "🧹 Cleaning up validation resource group..." "Yellow"
    az group delete --name $ResourceGroupName --yes --no-wait --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ ARM template validation passed" "Green"
        if ($Detailed) {
            Write-ColorOutput "📊 Validation details:" "Cyan"
            Write-ColorOutput $validationResult "White"
        }
        return $true
    } else {
        Write-ColorOutput "❌ ARM template validation failed:" "Red"
        Write-ColorOutput $validationResult "Red"
        return $false
    }
}

function Test-WhatIfDeployment {
    param([string]$TemplateFile, [string]$ResourceGroupName, [string]$Location)
    
    Write-ColorOutput "🔍 Running what-if deployment analysis..." "Cyan"
    
    # Create temporary resource group for what-if
    Write-ColorOutput "📦 Creating temporary what-if resource group..." "Yellow"
    az group create --name "${ResourceGroupName}-whatif" --location $Location --output none
    
    # Build what-if command
    $whatifCmd = @(
        "az", "deployment", "group", "what-if"
        "--resource-group", "${ResourceGroupName}-whatif"
        "--template-file", $TemplateFile
        "--parameters"
        "sqlAdministratorLogin=whatifsqladmin"
        "sqlAdministratorLoginPassword=WhatIfSqlPass123!"
        "vmAdminUsername=whatifvmadmin"
        "vmAdminPassword=WhatIfVmPass123!"
        "vmSizeOption=Non-Overlake"
    )
    
    # Add parameters file if specified
    if ($ParametersFile -and (Test-Path $ParametersFile)) {
        $whatifCmd += @("--parameters", "@$ParametersFile")
    }
    
    # Execute what-if
    $whatifResult = & $whatifCmd[0] $whatifCmd[1..($whatifCmd.Length-1)] 2>&1
    
    # Clean up temporary resource group
    Write-ColorOutput "🧹 Cleaning up what-if resource group..." "Yellow"
    az group delete --name "${ResourceGroupName}-whatif" --yes --no-wait --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ What-if analysis completed successfully" "Green"
        if ($Detailed) {
            Write-ColorOutput "📊 What-if results:" "Cyan"
            Write-ColorOutput $whatifResult "White"
        }
        return $true
    } else {
        Write-ColorOutput "❌ What-if analysis failed:" "Red"
        Write-ColorOutput $whatifResult "Red"
        return $false
    }
}

function Get-TemplateInfo {
    param([string]$TemplateFile)
    
    Write-ColorOutput "📄 Template Information:" "Cyan"
    Write-ColorOutput "======================" "Cyan"
    
    try {
        # Get file info
        $fileInfo = Get-Item $TemplateFile
        Write-ColorOutput "📁 File: $($fileInfo.Name)" "White"
        Write-ColorOutput "📏 Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" "White"
        Write-ColorOutput "📅 Modified: $($fileInfo.LastWriteTime)" "White"
        
        # Analyze template content
        $content = Get-Content $TemplateFile -Raw
        $lines = ($content -split '\n').Count
        $paramCount = ([regex]::Matches($content, 'param\s+\w+')).Count
        $resourceCount = ([regex]::Matches($content, 'resource\s+\w+')).Count
        $outputCount = ([regex]::Matches($content, 'output\s+\w+')).Count
        
        Write-ColorOutput "📏 Lines: $lines" "White"
        Write-ColorOutput "🔧 Parameters: $paramCount" "White"
        Write-ColorOutput "🏗️  Resources: $resourceCount" "White"
        Write-ColorOutput "📊 Outputs: $outputCount" "White"
        
    } catch {
        Write-ColorOutput "❌ Failed to analyze template: $_" "Red"
    }
    
    Write-ColorOutput "" "White"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "✅ Private Endpoint to SQL Server DB Template Validator" "Magenta"
Write-ColorOutput "========================================================" "Magenta"

# Set subscription if provided
if ($SubscriptionId) {
    Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
    az account set --subscription $SubscriptionId
}

Write-ColorOutput "" "White"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed" "Red"
    exit 1
}

Write-ColorOutput "" "White"

# Validate template file exists
if (-not (Test-FileExists -FilePath $TemplateFile -Description "Bicep template")) {
    exit 1
}

# Validate parameters file if specified
if ($ParametersFile -and -not (Test-FileExists -FilePath $ParametersFile -Description "Parameters file")) {
    exit 1
}

Write-ColorOutput "" "White"

# Show template information
Get-TemplateInfo -TemplateFile $TemplateFile

# Run validation tests
$validationTests = @(
    @{ Name = "Bicep Syntax"; Test = { Test-BicepSyntax -TemplateFile $TemplateFile } },
    @{ Name = "ARM Validation"; Test = { Test-TemplateValidation -TemplateFile $TemplateFile -ResourceGroupName $ResourceGroupName -Location $Location } },
    @{ Name = "What-If Analysis"; Test = { Test-WhatIfDeployment -TemplateFile $TemplateFile -ResourceGroupName $ResourceGroupName -Location $Location } }
)

$passedTests = 0
$totalTests = $validationTests.Count

Write-ColorOutput "🧪 Running Validation Tests" "Cyan"
Write-ColorOutput "===========================" "Cyan"

foreach ($test in $validationTests) {
    Write-ColorOutput "" "White"
    Write-ColorOutput "▶️  $($test.Name)" "Yellow"
    Write-ColorOutput "─────────────────" "Yellow"
    
    $result = & $test.Test
    if ($result) {
        $passedTests++
    }
}

# Summary
Write-ColorOutput "" "White"
Write-ColorOutput "📊 VALIDATION SUMMARY" "Cyan"
Write-ColorOutput "====================" "Cyan"
Write-ColorOutput "✅ Tests passed: $passedTests/$totalTests" "Green"

if ($passedTests -eq $totalTests) {
    Write-ColorOutput "🎉 All validation tests passed! Template is ready for deployment." "Green"
    exit 0
} else {
    Write-ColorOutput "❌ Some validation tests failed. Please review the errors above." "Red"
    exit 1
}