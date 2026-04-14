#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for VM_NATGateway Bicep template

.DESCRIPTION
    This script validates the Bicep template syntax, parameters, and deployment readiness.
    It performs comprehensive checks without deploying actual resources.

.PARAMETER TemplateFile
    Path to the Bicep template file (default: main.bicep)

.PARAMETER ResourceGroupName
    Name of the resource group for validation context (default: rg-vm-natgateway-validate)

.PARAMETER Location
    Azure region for validation (default: southeastasia)

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
    [string]$ResourceGroupName = "rg-vm-natgateway-validate",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

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
        "adminUsername=validationuser"
        "adminPasswordOrKey=ValidationPass123!"
        "authenticationType=password"
        "vmSizeOption=Non-Overlake"
    )

    # Execute validation
    $validationResult = & $validateCmd[0] $validateCmd[1..($validateCmd.Length-1)] 2>&1
    $validationExitCode = $LASTEXITCODE

    # Clean up temporary resource group
    Write-ColorOutput "🧹 Cleaning up validation resource group..." "Yellow"
    az group delete --name $ResourceGroupName --yes --no-wait --output none

    if ($validationExitCode -eq 0) {
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

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔍 VM_NATGateway Template Validation" "Cyan"
Write-ColorOutput "======================================" "Cyan"

$allPassed = $true

# Step 1: Prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed." "Red"
    exit 1
}

# Step 2: File existence check
Write-ColorOutput "`n🔍 Checking project files..." "Cyan"
$fileCheck = Test-FileExists -FilePath $TemplateFile -Description "Bicep template"
$fileCheck = (Test-FileExists -FilePath "deploy.ps1" -Description "Deploy script") -and $fileCheck
$fileCheck = (Test-FileExists -FilePath "cleanup.ps1" -Description "Cleanup script") -and $fileCheck
$fileCheck = (Test-FileExists -FilePath "PROJECT_SUMMARY.md" -Description "Project summary") -and $fileCheck
$fileCheck = (Test-FileExists -FilePath "Readme.md" -Description "Readme") -and $fileCheck

if (-not $fileCheck) {
    $allPassed = $false
}

# Step 3: Bicep syntax validation
Write-ColorOutput "" "White"
if (-not (Test-BicepSyntax -TemplateFile $TemplateFile)) {
    $allPassed = $false
}

# Step 4: ARM template validation
Write-ColorOutput "" "White"
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}
if (-not (Test-TemplateValidation -TemplateFile $TemplateFile -ResourceGroupName $ResourceGroupName -Location $Location)) {
    $allPassed = $false
}

# Summary
Write-ColorOutput "" "White"
Write-ColorOutput "======================================" "Cyan"
if ($allPassed) {
    Write-ColorOutput "🎉 All validation tests passed!" "Green"
    exit 0
} else {
    Write-ColorOutput "❌ Some validation tests failed" "Red"
    exit 1
}
