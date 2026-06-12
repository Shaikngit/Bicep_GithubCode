#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-mtu-lab-eastus2",

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "main.bicep",

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "parameters.json",

    [Parameter(Mandatory = $false)]
    [string]$DeploymentName = "mtu-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Invoke-AzCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
}

function Test-AzureCli {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI was not found in PATH. Install Azure CLI first."
    }
}

function Test-AzureLogin {
    az account show --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI is not logged in. Run: az login"
    }
}

function ConvertTo-PlainText {
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecureValue
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

Test-AzureCli
Test-AzureLogin

Write-Host "Ensuring Bicep CLI is available..."
Invoke-AzCli -Arguments @("bicep", "install", "--output", "none")

if (-not (Test-Path -Path $TemplateFile -PathType Leaf)) {
    throw "Template file not found: $TemplateFile"
}

if (-not (Test-Path -Path $ParameterFile -PathType Leaf)) {
    throw "Parameter file not found: $ParameterFile"
}

$parameterContent = Get-Content -Path $ParameterFile -Raw | ConvertFrom-Json
$adminPasswordFromFile = $parameterContent.parameters.adminPassword.value
$adminPasswordOverride = $null

if ([string]::IsNullOrWhiteSpace($adminPasswordFromFile) -or $adminPasswordFromFile -eq "REPLACE_WITH_STRONG_PASSWORD") {
    Write-Host "adminPassword is not set in $ParameterFile."
    $securePassword = Read-Host "Enter admin password for VM deployment" -AsSecureString
    $adminPasswordOverride = ConvertTo-PlainText -SecureValue $securePassword
}

Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..."
Invoke-AzCli -Arguments @("group", "create", "--name", $ResourceGroupName, "--location", $Location, "--output", "none")

if ($WhatIf) {
    Write-Host "Running what-if deployment '$DeploymentName'..."
    $whatIfArgs = @(
        "deployment", "group", "what-if",
        "--resource-group", $ResourceGroupName,
        "--name", $DeploymentName,
        "--template-file", $TemplateFile,
        "--parameters", "@$ParameterFile",
        "--output", "table"
    )

    if ($null -ne $adminPasswordOverride) {
        $whatIfArgs += @("--parameters", "adminPassword=$adminPasswordOverride")
    }

    Invoke-AzCli -Arguments $whatIfArgs
    exit 0
}

Write-Host "Starting deployment '$DeploymentName'..."
$deployArgs = @(
    "deployment", "group", "create",
    "--resource-group", $ResourceGroupName,
    "--name", $DeploymentName,
    "--template-file", $TemplateFile,
    "--parameters", "@$ParameterFile",
    "--output", "json"
)

if ($null -ne $adminPasswordOverride) {
    $deployArgs += @("--parameters", "adminPassword=$adminPasswordOverride")
}

$deploymentJson = & az @deployArgs
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: az $($deployArgs -join ' ')"
}

$deploymentJson | Out-File -FilePath deployment-outputs.json -Encoding utf8

Write-Host "Deployment complete. Key outputs:"
Invoke-AzCli -Arguments @(
    "deployment", "group", "show",
    "--resource-group", $ResourceGroupName,
    "--name", $DeploymentName,
    "--query", "properties.outputs",
    "--output", "table"
)

Write-Host "Saved full deployment response to deployment-outputs.json"

$sourcePublicIp = & az deployment group show `
    --resource-group $ResourceGroupName `
    --name $DeploymentName `
    --query "properties.outputs.sourceVmPublicIp.value" `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed while reading source VM public IP output."
}

Write-Host "Source public IP: $sourcePublicIp"
