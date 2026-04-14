---
name: bicep-scaffold
description: 'Boilerplate templates for Bicep lab project files. Use when: new project template, scaffold files, blank deploy script, blank validate script, blank cleanup script, starter main.bicep, project boilerplate, file template.'
argument-hint: 'Which file template? (main.bicep, deploy.ps1, validate.ps1, cleanup.ps1, PROJECT_SUMMARY.md, Readme.md)'
---

# Bicep Lab Project Scaffold

Provides ready-to-use boilerplate templates for all 6 required lab project files. Use these as starting points when creating new projects.

## When to Use

- Creating a new lab project and need starter files
- Adding missing files to an existing project
- Need the standard structure for a specific file type

## Templates

Use the templates below. Replace all `<PLACEHOLDERS>` with project-specific values.

---

### main.bicep

```bicep
// ============================================================================
// <PROJECT_NAME> — Bicep Template
// ============================================================================

// --- Authentication ---
@description('Administrator username')
param adminUsername string

@description('Administrator password or SSH public key')
@secure()
param adminPasswordOrKey string

// --- Resource Naming ---
@description('Name of the virtual machine')
param vmName string = '<default-vm-name>'

@description('Name of the virtual network')
param virtualNetworkName string = 'vNet'

@description('Name of the network security group')
param networkSecurityGroupName string = 'SecGroupNet'

// --- Size / SKU ---
@description('VM size option: Overlake or Non-Overlake')
@allowed(['Overlake', 'Non-Overlake'])
param vmSizeOption string = 'Non-Overlake'

// --- Network Addressing ---
@description('Virtual network address prefix')
param vNetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix')
param vNetSubnetAddressPrefix string = '10.0.0.0/24'

// --- Location (always last) ---
@description('Azure region for all resources')
param location string = resourceGroup().location

// ============================================================================
// Variables
// ============================================================================
var publicIPAddressName = '${vmName}PublicIP'
var networkInterfaceName = '${vmName}NetInt'
var subnetName = 'Subnet'
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'
var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

// ============================================================================
// Resources (order: NSG → VNet → PIP → NAT/Bastion → LB → NIC → VM → Ext)
// ============================================================================

// 1. Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      // Add rules here
    ]
  }
}

// 2. Virtual Network + Subnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [vNetAddressPrefix] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: vNetSubnetAddressPrefix
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// 3. Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIPAddressName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabelPrefix }
  }
}

// 4. Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: publicIP.id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// 5. Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
    }
    storageProfile: {
      // Configure OS disk and image here
    }
    networkProfile: {
      networkInterfaces: [{ id: nic.id }]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
output vmName string = vm.name
output publicIPAddress string = publicIP.properties.ipAddress
output fqdn string = publicIP.properties.dnsSettings.fqdn
```

---

### deploy.ps1

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys <PROJECT_NAME> Bicep template

.DESCRIPTION
    <DESCRIPTION_OF_WHAT_GETS_DEPLOYED>

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-<project-slug>)

.PARAMETER Location
    Azure region (default: southeastasia)

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd!"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-<project-slug>",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,

    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-AzureCLI {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "❌ Azure CLI not found. Install from https://aka.ms/installazurecli" "Red"
        exit 1
    }
    Write-ColorOutput "✅ Azure CLI found" "Green"
}

function Test-AzureLogin {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-ColorOutput "❌ Not logged in. Run 'az login' first." "Red"
        exit 1
    }
    Write-ColorOutput "✅ Logged in as: $($account.user.name)" "Green"
}

function Test-BicepCLI {
    $ver = az bicep version 2>$null
    if (-not $ver) {
        Write-ColorOutput "🔍 Installing Bicep CLI..." "Cyan"
        az bicep install
    }
    Write-ColorOutput "✅ Bicep CLI ready" "Green"
}

function Test-PasswordComplexity {
    param([string]$Password)
    if ($Password.Length -lt 12) { return $false }
    if ($Password -cnotmatch '[A-Z]') { return $false }
    if ($Password -cnotmatch '[a-z]') { return $false }
    if ($Password -notmatch '\d') { return $false }
    if ($Password -notmatch '[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]') { return $false }
    return $true
}

function Test-Prerequisites {
    Write-ColorOutput "`n🔍 Checking prerequisites..." "Cyan"
    Test-AzureCLI
    Test-AzureLogin
    Test-BicepCLI
    Write-ColorOutput "🎉 All prerequisites passed!`n" "Green"
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    Write-ColorOutput "`n⚠️  Estimated monthly cost: ~$<COST>/month" "Yellow"
    Write-ColorOutput "📦 Resource Group: $ResourceGroupName" "Cyan"
    Write-ColorOutput "🎯 Region: $Location" "Cyan"
    $response = Read-Host "`nProceed with deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    Write-ColorOutput "`n📦 Creating resource group: $ResourceGroupName..." "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"
        exit 1
    }

    Write-ColorOutput "🚀 Starting deployment..." "Cyan"
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file main.bicep `
        --parameters adminUsername=$AdminUsername adminPasswordOrKey=$AdminPasswordOrKey `
        --output table

    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "`n✅ Deployment succeeded!" "Green"
    } else {
        Write-ColorOutput "`n❌ Deployment failed!" "Red"
        exit 1
    }
}

# =============================================================================
# MAIN
# =============================================================================
Test-Prerequisites
if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "Deployment cancelled." "Yellow"
    exit 0
}
Start-Deployment
```

---

### validate.ps1

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Validation script for <PROJECT_NAME> Bicep template

.DESCRIPTION
    Validates Bicep syntax, parameters, and deployment readiness without deploying.

.PARAMETER TemplateFile
    Path to the Bicep template file (default: main.bicep)

.PARAMETER ResourceGroupName
    Temp resource group for validation (default: rg-<project-slug>-validate)

.PARAMETER Location
    Azure region (default: southeastasia)

.PARAMETER Detailed
    Show detailed validation output
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "main.bicep",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-<project-slug>-validate",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

$script:testsPassed = 0
$script:testsFailed = 0

# --- Test 1: Bicep Syntax ---
Write-ColorOutput "`n🔍 Test 1: Bicep syntax check..." "Cyan"
$tempDir = Join-Path $env:TEMP "bicep-validate-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
az bicep build --file $TemplateFile --outdir $tempDir 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ Bicep syntax valid" "Green"
    $script:testsPassed++
} else {
    Write-ColorOutput "❌ Bicep syntax errors found" "Red"
    $script:testsFailed++
}
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# --- Test 2: ARM Template Validation ---
Write-ColorOutput "`n🔍 Test 2: ARM template validation..." "Cyan"
az group create --name $ResourceGroupName --location $Location --output none 2>$null
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $TemplateFile `
    --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✅ ARM validation passed" "Green"
    $script:testsPassed++
} else {
    Write-ColorOutput "❌ ARM validation failed" "Red"
    $script:testsFailed++
}
az group delete --name $ResourceGroupName --yes --no-wait --output none 2>$null

# --- Summary ---
Write-ColorOutput "`n========================================" "White"
if ($script:testsFailed -eq 0) {
    Write-ColorOutput "🎉 All validation tests passed! ($script:testsPassed/$($script:testsPassed + $script:testsFailed))" "Green"
    exit 0
} else {
    Write-ColorOutput "❌ Some validation tests failed ($script:testsFailed failures)" "Red"
    exit 1
}
```

---

### cleanup.ps1

```powershell
# ============================================================================
# Azure Resource Group Cleanup Script
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not logged in. Run 'Connect-AzAccount' first." "ERROR"
            exit 1
        }
        Write-Log "Logged in as: $($context.Account.Id)" "SUCCESS"
    }
    catch {
        Write-Log "Error checking Azure login: $_" "ERROR"
        exit 1
    }
}

# --- Main ---
Write-Log "========================================" "INFO"
Write-Log "Azure Resource Group Cleanup" "INFO"
Write-Log "========================================" "INFO"

Test-AzureLogin

Write-Log "Checking resource group: $ResourceGroupName" "INFO"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Log "Resource group '$ResourceGroupName' not found." "WARNING"
    exit 0
}

$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
Write-Log "Found $($resources.Count) resources in '$ResourceGroupName'" "INFO"

if (-not $Force) {
    Write-Log "Resources to be deleted:" "WARNING"
    $resources | ForEach-Object { Write-Log "  - $($_.ResourceType): $($_.Name)" "WARNING" }
    $response = Read-Host "`nAre you sure you want to delete '$ResourceGroupName'? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Log "Cleanup cancelled." "INFO"
        exit 0
    }
}

Write-Log "Deleting resource group '$ResourceGroupName'..." "INFO"
$job = Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob
$job | Wait-Job | Out-Null
Write-Log "Resource group '$ResourceGroupName' deleted successfully!" "SUCCESS"
```

---

### PROJECT_SUMMARY.md

Use sections in this order:
1. `# <Project Name> - Project Summary`
2. `## 📁 File Structure` — tree diagram
3. `## 📊 Project Overview` — table (Name, Description, Use Case, Complexity ⭐, Deployment Time)
4. `## 🎯 Key Features` — bulleted ✅ list
5. `## 🚀 Quick Start Commands` — PowerShell examples
6. `## 🔧 Technical Specifications` — resource details
7. `## 🎨 Architecture Diagram` — Unicode box-drawing diagram

---

### Readme.md

Use sections in this order:
1. `# 🏗️ <Project Name>` — title with emoji
2. `## 🎯 Overview` — 2-3 sentences
3. `## 🏛️ Architecture` — ASCII diagram + component list
4. `## 📋 Features` — bullet list
5. `## 🔧 Parameters` — markdown table
6. `## 🚀 Quick Deploy` — step-by-step CLI commands
7. `## 🧪 Testing` — verification steps
8. `## 💰 Estimated Cost` — monthly cost breakdown
9. `## 📚 References` — Azure docs links
