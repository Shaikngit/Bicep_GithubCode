#Requires -Version 7.0
param(
    [Parameter(Mandatory=$false)][string]$TemplateFile = "main.bicep",
    [Parameter(Mandatory=$false)][switch]$Detailed
)

function Write-ColorOutput { param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White; "Magenta" = [ConsoleColor]::Magenta }
    Write-Host $Message -ForegroundColor $colors[$Color] }

function Test-BicepSyntax {
    Write-ColorOutput "🔍 Validating Bicep syntax..." "Cyan"
    $buildResult = az bicep build --file $TemplateFile --outdir "temp" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Bicep syntax validation passed" "Green"
        if (Test-Path "temp") { Remove-Item "temp" -Force -Recurse -ErrorAction SilentlyContinue }; return $true
    } else { Write-ColorOutput "❌ Bicep syntax validation failed:" "Red"; Write-ColorOutput $buildResult "Red"; return $false }
}

function Test-TemplateValidation {
    Write-ColorOutput "🔍 Running ARM template validation..." "Cyan"
    $tempRg = "rg-pe-pls-validate-temp"; az group create --name $tempRg --location "eastus" --output none
    $validateResult = az deployment group validate --resource-group $tempRg --template-file $TemplateFile --parameters vmAdminUsername=validateuser vmAdminPassword=ValidatePass123! vmSizeOption=Non-Overlake allowedRdpSourceAddress=0.0.0.0/0 useCustomImage=No 2>&1
    az group delete --name $tempRg --yes --no-wait --output none
    if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✅ ARM template validation passed" "Green"; if ($Detailed) { Write-ColorOutput $validateResult "White" }; return $true }
    else { Write-ColorOutput "❌ ARM template validation failed:" "Red"; Write-ColorOutput $validateResult "Red"; return $false }
}

Write-ColorOutput "✅ Private Endpoint + Private Link Service Template Validator" "Magenta"
Write-ColorOutput "============================================================" "Magenta"

if (-not (Test-Path $TemplateFile)) { Write-ColorOutput "❌ Template file not found: $TemplateFile" "Red"; exit 1 }

$tests = @(@{ Name = "Bicep Syntax"; Test = { Test-BicepSyntax } }, @{ Name = "ARM Validation"; Test = { Test-TemplateValidation } })
$passed = 0; foreach ($test in $tests) { Write-ColorOutput "▶️  $($test.Name)" "Yellow"; if (& $test.Test) { $passed++ } }

Write-ColorOutput "📊 VALIDATION SUMMARY" "Cyan"
Write-ColorOutput "✅ Tests passed: $passed/$($tests.Count)" "Green"
if ($passed -eq $tests.Count) { Write-ColorOutput "🎉 All validation tests passed!" "Green"; exit 0 } else { Write-ColorOutput "❌ Some validation tests failed" "Red"; exit 1 }