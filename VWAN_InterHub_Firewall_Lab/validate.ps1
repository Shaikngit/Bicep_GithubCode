#!/usr/bin/env pwsh

<#
.SYNOPSIS
Validate Azure Virtual WAN Inter-Hub Traffic Inspection Lab Bicep Templates

.DESCRIPTION
This script validates all Bicep templates in the lab without deploying resources.
It checks for syntax errors, template validation, and what-if analysis.

.PARAMETER SkipWhatIf
Skip the what-if analysis (faster validation)

.PARAMETER Location
Location for validation deployment
Default: southeastasia

.EXAMPLE
./validate.ps1

.EXAMPLE
./validate.ps1 -SkipWhatIf -Location "eastus"
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipWhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia"
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

function Test-BicepSyntax {
    param([string]$TemplatePath)
    
    Write-ColorOutput "🔍 Checking Bicep syntax: $TemplatePath" "Yellow"
    
    # Check if this is a parameters file
    if ($TemplatePath.EndsWith(".bicepparam")) {
        # For parameter files, just check if they can be parsed by trying a validation
        try {
            $templateFile = $TemplatePath.Replace(".bicepparam", ".bicep")
            if (Test-Path $templateFile) {
                # Test validation with a dummy password
                $result = az deployment sub validate `
                    --location "southeastasia" `
                    --template-file $templateFile `
                    --parameters $TemplatePath `
                    --parameters adminPassword="TestPassword123!" `
                    --output none 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "✅ Parameters file validation passed: $TemplatePath" "Green"
                    return $true
                } else {
                    Write-ColorOutput "❌ Parameters file validation failed: $TemplatePath" "Red"
                    return $false
                }
            } else {
                Write-ColorOutput "⚠️  Skipping parameters file (no matching .bicep file): $TemplatePath" "Yellow"
                return $true
            }
        }
        catch {
            Write-ColorOutput "❌ Error validating parameters file: $TemplatePath - $($_.Exception.Message)" "Red"
            return $false
        }
    } else {
        # Regular Bicep file syntax check
        try {
            $result = az bicep build --file $TemplatePath --stdout 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Syntax validation passed: $TemplatePath" "Green"
                return $true
            } else {
                Write-ColorOutput "❌ Syntax validation failed: $TemplatePath" "Red"
                return $false
            }
        }
        catch {
            Write-ColorOutput "❌ Error checking syntax: $TemplatePath - $($_.Exception.Message)" "Red"
            return $false
        }
    }
}

function Test-TemplateValidation {
    param([string]$TemplatePath, [string]$TestLocation)
    
    Write-ColorOutput "🔍 Template validation: $TemplatePath" "Yellow"
    
    try {
        $result = az deployment sub validate `
            --location $TestLocation `
            --template-file $TemplatePath `
            --parameters resourceGroupName=validation-test `
            --parameters adminPassword=TestPassword123! `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Template validation passed: $TemplatePath" "Green"
            return $true
        } else {
            Write-ColorOutput "❌ Template validation failed: $TemplatePath" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Error validating template: $TemplatePath - $($_.Exception.Message)" "Red"
        return $false
    }
}

function Test-WhatIfDeployment {
    param([string]$TemplatePath, [string]$TestLocation)
    
    Write-ColorOutput "🔍 What-If analysis: $TemplatePath" "Yellow"
    
    try {
        $result = az deployment sub what-if `
            --location $TestLocation `
            --template-file $TemplatePath `
            --parameters resourceGroupName=validation-test `
            --parameters adminPassword=TestPassword123! `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ What-If analysis passed: $TemplatePath" "Green"
            return $true
        } else {
            Write-ColorOutput "❌ What-If analysis failed: $TemplatePath" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Error in What-If analysis: $TemplatePath - $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main validation
try {
    Write-ColorOutput "🔥 Azure Virtual WAN Lab - Template Validation" "Cyan"
    Write-ColorOutput "==============================================" "Cyan"
    
    # Check if Azure CLI is available
    try {
        az version --output none
        Write-ColorOutput "✅ Azure CLI is available" "Green"
    }
    catch {
        Write-ColorOutput "❌ Azure CLI is not installed" "Red"
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure: $($account.user.name)" "Green"
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Run 'az login' first." "Red"
        exit 1
    }
    
    $allPassed = $true
    
    # Test main template
    $mainTemplate = "main.bicep"
    
    if (Test-Path $mainTemplate) {
        # Syntax check
        if (-not (Test-BicepSyntax $mainTemplate)) {
            $allPassed = $false
        }
        
        # Template validation
        if (-not (Test-TemplateValidation $mainTemplate $Location)) {
            $allPassed = $false
        }
        
        # What-If analysis
        if (-not $SkipWhatIf) {
            if (-not (Test-WhatIfDeployment $mainTemplate $Location)) {
                $allPassed = $false
            }
        }
    } else {
        Write-ColorOutput "❌ Main template not found: $mainTemplate" "Red"
        $allPassed = $false
    }
    
    # Test all module templates
    $moduleFiles = Get-ChildItem -Path "modules" -Filter "*.bicep" -ErrorAction SilentlyContinue
    
    foreach ($moduleFile in $moduleFiles) {
        $modulePath = $moduleFile.FullName
        Write-ColorOutput "`n🔍 Testing module: $($moduleFile.Name)" "Blue"
        
        if (-not (Test-BicepSyntax $modulePath)) {
            $allPassed = $false
        }
    }
    
    # Check for parameters file
    $parametersFile = "main.bicepparam"
    if (Test-Path $parametersFile) {
        Write-ColorOutput "`n🔍 Testing parameters file: $parametersFile" "Blue"
        Write-ColorOutput "ℹ️  Note: Parameter file requires adminPassword to be provided at deployment" "Blue"
        
        # For parameter files, we'll just check that they reference the correct template
        try {
            $paramContent = Get-Content $parametersFile -Raw
            if ($paramContent -match "using\s+'main\.bicep'") {
                Write-ColorOutput "✅ Parameters file syntax is valid: $parametersFile" "Green"
            } else {
                Write-ColorOutput "❌ Parameters file does not reference main.bicep correctly" "Red"
                $allPassed = $false
            }
        }
        catch {
            Write-ColorOutput "❌ Error reading parameters file: $($_.Exception.Message)" "Red"
            $allPassed = $false
        }
    }
    
    # Summary
    Write-ColorOutput "`n📋 VALIDATION SUMMARY" "Cyan"
    Write-ColorOutput "=====================" "Cyan"
    
    if ($allPassed) {
        Write-ColorOutput "✅ All validations passed!" "Green"
        Write-ColorOutput "🚀 Templates are ready for deployment." "Green"
        
        Write-ColorOutput "`n📖 To deploy the lab:" "White"
        Write-ColorOutput "./deploy.ps1 -AdminPassword 'YourStrongPassword123!'" "Green"
        
        Write-ColorOutput "`n📖 To deploy with custom parameters:" "White"
        Write-ColorOutput "./deploy.ps1 -ResourceGroupName 'my-lab' -Location '$Location' -AdminPassword 'YourStrongPassword123!'" "Green"
    } else {
        Write-ColorOutput "❌ Some validations failed!" "Red"
        Write-ColorOutput "🔧 Please fix the errors above before deployment." "Yellow"
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Validation script failed: $($_.Exception.Message)" "Red"
    exit 1
}

Write-ColorOutput "`n✨ Validation completed." "Green"