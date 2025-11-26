#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for Azure Firewall DNAT + Internal LB Bicep template

.DESCRIPTION
    Validates the complex networking template including Azure Firewall, load balancers,
    and multi-VNet architecture.

.PARAMETER TemplateFile
    Path to the Bicep template file (default: main.bicep)

.PARAMETER Detailed
    Show detailed validation output including resource dependencies

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

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    $allGood = $true
    
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
    } catch {
        Write-ColorOutput "❌ Azure CLI not found" "Red"; $allGood = $false
    }
    
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name)" "Green"
    } catch {
        Write-ColorOutput "❌ Not logged into Azure" "Red"; $allGood = $false
    }
    
    try {
        $version = az bicep version
        Write-ColorOutput "✅ Bicep CLI version: $version" "Green"
    } catch {
        Write-ColorOutput "❌ Bicep CLI not found" "Red"; $allGood = $false
    }
    
    return $allGood
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
    
    # Create temp resource group for validation
    $tempRg = "rg-firewall-dnat-validate-temp"
    Write-ColorOutput "📦 Creating temporary validation resource group..." "Yellow"
    az group create --name $tempRg --location "southeastasia" --output none
    
    # Run validation with dummy parameters
    $validateResult = az deployment group validate `
        --resource-group $tempRg `
        --template-file $TemplateFile `
        --parameters `
        adminUsername=validateuser `
        adminPassword=ValidatePass123! `
        vmSizeOption=Non-Overlake `
        vmNamePrefix=TestVM `
        2>&1
    
    # Cleanup temp resource group
    Write-ColorOutput "🧹 Cleaning up validation resource group..." "Yellow"
    az group delete --name $tempRg --yes --no-wait --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ ARM template validation passed" "Green"
        if ($Detailed) {
            Write-ColorOutput "📊 Validation details:" "Cyan"
            Write-ColorOutput $validateResult "White"
        }
        return $true
    } else {
        Write-ColorOutput "❌ ARM template validation failed:" "Red"
        Write-ColorOutput $validateResult "Red"
        return $false
    }
}

function Test-WhatIfDeployment {
    Write-ColorOutput "🔍 Running what-if deployment analysis..." "Cyan"
    
    # Create temp resource group for what-if
    $tempRg = "rg-firewall-dnat-whatif-temp"
    Write-ColorOutput "📦 Creating temporary what-if resource group..." "Yellow"
    az group create --name $tempRg --location "southeastasia" --output none
    
    # Run what-if analysis
    $whatifResult = az deployment group what-if `
        --resource-group $tempRg `
        --template-file $TemplateFile `
        --parameters `
        adminUsername=whatifuser `
        adminPassword=WhatIfPass123! `
        vmSizeOption=Non-Overlake `
        vmNamePrefix=WhatIfVM `
        2>&1
    
    # Cleanup temp resource group
    Write-ColorOutput "🧹 Cleaning up what-if resource group..." "Yellow"
    az group delete --name $tempRg --yes --no-wait --output none
    
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

function Get-TemplateComplexityInfo {
    Write-ColorOutput "📄 Template Complexity Analysis:" "Cyan"
    Write-ColorOutput "================================" "Cyan"
    
    try {
        $content = Get-Content $TemplateFile -Raw
        $lines = ($content -split '\n').Count
        $paramCount = ([regex]::Matches($content, 'param\s+\w+')).Count
        $resourceCount = ([regex]::Matches($content, 'resource\s+\w+')).Count
        $outputCount = ([regex]::Matches($content, 'output\s+\w+')).Count
        $moduleCount = ([regex]::Matches($content, 'module\s+\w+')).Count
        
        # Analyze specific Azure resources
        $firewallCount = ([regex]::Matches($content, 'Microsoft\.Network/azureFirewalls')).Count
        $vnetCount = ([regex]::Matches($content, 'Microsoft\.Network/virtualNetworks')).Count
        $lbCount = ([regex]::Matches($content, 'Microsoft\.Network/loadBalancers')).Count
        $vmCount = ([regex]::Matches($content, 'Microsoft\.Compute/virtualMachines')).Count
        
        Write-ColorOutput "📏 Template Size: $lines lines" "White"
        Write-ColorOutput "🔧 Parameters: $paramCount" "White"
        Write-ColorOutput "🏗️  Resources: $resourceCount" "White"
        Write-ColorOutput "📊 Outputs: $outputCount" "White"
        Write-ColorOutput "📦 Modules: $moduleCount" "White"
        Write-ColorOutput "" "White"
        Write-ColorOutput "🔥 Azure Firewalls: $firewallCount" "Yellow"
        Write-ColorOutput "🌐 Virtual Networks: $vnetCount" "Yellow"
        Write-ColorOutput "⚖️  Load Balancers: $lbCount" "Yellow"
        Write-ColorOutput "💻 Virtual Machines: $vmCount" "Yellow"
        
        # Complexity assessment
        $complexityScore = $resourceCount + ($firewallCount * 5) + ($vnetCount * 2) + ($lbCount * 3)
        if ($complexityScore -lt 10) {
            Write-ColorOutput "📊 Complexity: Low ($complexityScore)" "Green"
        } elseif ($complexityScore -lt 25) {
            Write-ColorOutput "📊 Complexity: Medium ($complexityScore)" "Yellow"
        } else {
            Write-ColorOutput "📊 Complexity: High ($complexityScore)" "Red"
        }
        
    } catch {
        Write-ColorOutput "❌ Failed to analyze template: $_" "Red"
    }
    
    Write-ColorOutput "" "White"
}

# Main validation script
Write-ColorOutput "✅ Firewall DNAT + Internal LB Template Validator" "Magenta"
Write-ColorOutput "=================================================" "Magenta"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed" "Red"
    exit 1
}

Write-ColorOutput "" "White"

# Check template file
if (-not (Test-Path $TemplateFile)) {
    Write-ColorOutput "❌ Template file not found: $TemplateFile" "Red"
    exit 1
}

Write-ColorOutput "" "White"

# Show template complexity
Get-TemplateComplexityInfo

# Run validation tests
$validationTests = @(
    @{ Name = "Bicep Syntax"; Test = { Test-BicepSyntax } },
    @{ Name = "ARM Template Validation"; Test = { Test-TemplateValidation } },
    @{ Name = "What-If Analysis"; Test = { Test-WhatIfDeployment } }
)

$passedTests = 0
$totalTests = $validationTests.Count

Write-ColorOutput "🧪 Running Validation Tests" "Cyan"
Write-ColorOutput "===========================" "Cyan"

foreach ($test in $validationTests) {
    Write-ColorOutput "" "White"
    Write-ColorOutput "▶️  $($test.Name)" "Yellow"
    Write-ColorOutput "─────────────────────────────" "Yellow"
    
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
    Write-ColorOutput "🎉 All validation tests passed! Complex template is ready for deployment." "Green"
    Write-ColorOutput "⚠️  Note: This is a high-cost deployment (~$1200+/month)" "Yellow"
    exit 0
} else {
    Write-ColorOutput "❌ Some validation tests failed. Please review the errors above." "Red"
    exit 1
}