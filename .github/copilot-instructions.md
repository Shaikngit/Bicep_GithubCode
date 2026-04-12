# Copilot Instructions — Bicep Lab Projects

This workspace contains Azure Bicep lab deployments. Every new project **must** follow the established conventions below.

---

## Project Folder Structure

Each project lives in its own top-level folder and contains these files:

```
ProjectName/
├── main.bicep            # Primary Bicep template
├── deploy.ps1            # Deployment script (PowerShell 7+)
├── validate.ps1          # Pre-deployment validation script
├── cleanup.ps1           # Resource group deletion script
├── PROJECT_SUMMARY.md    # Detailed project summary
└── Readme.md             # Quick-start documentation
```

> **File naming**: Use `main.bicep` (not `azuredeploy.bicep`).

---

## Bicep Conventions (`main.bicep`)

### Parameter Ordering & Style

1. **Authentication** — `adminUsername`, `adminPassword` / `adminPasswordOrKey`
2. **Resource naming** — `vmName`, `virtualNetworkName`, etc.
3. **Size / SKU selection** — `vmSizeOption`, `ubuntuOSVersion`, `securityType`
4. **Network addressing** — `vNetAddressPrefix`, `vNetSubnetAddressPrefix`
5. **Location** — always last: `param location string = resourceGroup().location`
6. **Feature toggles** — `useCustomImage`, `authenticationType`

Rules:
- Every parameter **must** have a `@description()` decorator.
- Sensitive values **must** use `@secure()`.
- Enumerated choices **must** use `@allowed()`.
- Numeric bounds use `@minValue()` / `@maxValue()`.
- Use **camelCase** for all parameter names.

### Variable Patterns

```bicep
// Resource name derivation — use string interpolation
var publicIPAddressName = '${vmName}PublicIP'
var networkInterfaceName = '${vmName}NetInt'

// Global uniqueness — use uniqueString(resourceGroup().id)
var storageAccountName = uniqueString(resourceGroup().id)
var dnsLabelPrefix      = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

// Length-limited names — use take()
var vmName = take('mySvcVm${uniqueString(resourceGroup().id)}', 15)

// VM size selection — Overlake vs Non-Overlake pattern
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

// OS image lookup — use object map keyed by parameter
var imageReference = {
  'Ubuntu-2004': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}

// SSH / security config — use object variables
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

var securityProfileJson = {
  uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
  securityType: securityType
}
```

### Resource Declaration Order

Declare resources in this sequence:

1. Network Security Groups (NSGs)
2. Virtual Networks & Subnets
3. Public IP Addresses
4. NAT Gateways / Bastion Hosts
5. Load Balancers
6. Network Interfaces
7. Virtual Machines
8. VM Extensions
9. Private Endpoints / Private Link Services / Private DNS Zones
10. Storage Accounts / Databases / Other PaaS resources

### Resource Naming & API Versions

- Use recent stable API versions (prefer `@2023-09-01` for networking, `@2023-09-01` for compute).
- Symbolic resource names use **camelCase** without the provider prefix (e.g., `resource virtualNetwork`, `resource networkSecurityGroup`).
- Use `location: location` on every resource (never hard-code a region). Exception: Private DNS zones use `location: 'global'`.

### Network Addressing Standards

| Purpose | CIDR |
|---------|------|
| VNet address space | `10.x.0.0/16` |
| Regular subnets | `/24` |
| Bastion subnet (`AzureBastionSubnet`) | `/26` or larger |
| Firewall subnet (`AzureFirewallSubnet`) | `/24` |

- Use **reserved subnet names** for Azure services: `AzureBastionSubnet`, `AzureFirewallSubnet`.
- For Private Link scenarios, set `privateLinkServiceNetworkPolicies: 'Disabled'` on the service subnet.

### NSG Rules

```bicep
{
  name: 'SSH'          // or 'RDP' for Windows
  properties: {
    priority: 1000
    protocol: 'Tcp'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '22'   // '3389' for Windows
  }
}
```

- Priority **100–200** for common/primary rules; **1000+** for secondary.
- Always specify all six required fields (`priority`, `protocol`, `access`, `direction`, source & destination).

### VM Configuration

**Linux VMs:**
- Support both `password` and `sshPublicKey` authentication via `authenticationType` parameter.
- Apply `linuxConfiguration` conditionally: `((authenticationType == 'password') ? null : linuxConfiguration)`.
- Support Trusted Launch: `securityProfile: (securityType == 'TrustedLaunch') ? securityProfileJson : null`.
- OS disk: `createOption: 'FromImage'`, `storageAccountType: 'Standard_LRS'`.

**Windows VMs:**
- Image: `MicrosoftWindowsServer / WindowsServer / 2019-Datacenter / latest`.
- OS disk: `storageAccountType: 'StandardSSD_LRS'`, `diskSizeGB: 127`.
- Enable `provisionVMAgent: true` and `enableAutomaticUpdates: true`.
- IIS install via `CustomScriptExtension` with inline PowerShell.

**Custom Image Support** (optional):
- Toggle with `@allowed(['Yes', 'No']) param useCustomImage string = 'No'`.
- Conditionally use a gallery image resource ID.

### Dependencies

- Prefer **implicit** dependencies (reference another resource's `.id` or `.properties`).
- Use explicit `dependsOn` only when no property reference creates the dependency (e.g., loop-based resources).

### Outputs

Provide helpful outputs at the bottom of the file:

```bicep
output adminUsername string = adminUsername
output hostname string = publicIPAddress.properties.dnsSettings.fqdn
output sshCommand string = 'ssh ${adminUsername}@${publicIPAddress.properties.dnsSettings.fqdn}'
```

### Tags

Add `tags` with a `displayName` on resources where useful:

```bicep
tags: {
  displayName: networkInterfaceName
}
```

---

## PowerShell Deploy Script (`deploy.ps1`)

### Header

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys <Project Name> Bicep template

.DESCRIPTION
    <Detailed description of what gets deployed, including resource list and purpose.>

.PARAMETER ResourceGroupName
    Name of the resource group (default: rg-<project-slug>)

.PARAMETER Location
    Azure region (default: southeastasia)

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd!"
#>
```

### Standard Parameters

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-<project-slug>",

    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,

    [Parameter(Mandatory=$true)]
    [string]$AdminPasswordOrKey,

    # Add project-specific params here with ValidateSet where applicable

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)
```

> Default location is **southeastasia** unless the project requires a different region.

### Required Helper Functions

Every deploy script must include:

| Function | Purpose |
|----------|---------|
| `Write-ColorOutput` | Colored console output (Red, Green, Yellow, Cyan, White) |
| `Test-AzureCLI` | Verify `az` is installed |
| `Test-AzureLogin` | Verify active Azure session |
| `Test-BicepCLI` | Verify/install Bicep CLI |
| `Test-PasswordComplexity` | 12+ chars, upper, lower, digit, special |
| `Test-SSHKeyFormat` | _(Linux only)_ validate SSH public key |
| `Test-Prerequisites` | Orchestrate all checks above |
| `Get-UserConfirmation` | Show cost estimate, prompt unless `-Force` |
| `Start-Deployment` | Create RG, run `az deployment group create` |

### Console Output Style

Use emoji + color prefixes consistently:

```
🔍  — checking / searching (Cyan)
✅  — success (Green)
❌  — failure (Red)
⚠️   — warning / cost notice (Yellow)
📦  — creating resources (Cyan)
🎯  — setting targets (Cyan)
🚀  — starting deployment (Cyan)
🎉  — all passed / done (Green)
```

### Deployment Flow

```
1. Test-Prerequisites  →  exit 1 on failure
2. Get-UserConfirmation (show estimated monthly cost)  →  exit 0 if declined
3. Start-Deployment:
   a. Set subscription (if param provided)
   b. az group create --name $RG --location $Location --output none
   c. az deployment group create ... --parameters key=value
   d. Check $LASTEXITCODE → print success or failure
```

### Error Handling

- Check `$LASTEXITCODE -ne 0` after every `az` command.
- Use `try/catch` for PowerShell cmdlet calls.
- Redirect stderr with `2>$null` when output is parsed.

---

## PowerShell Cleanup Script (`cleanup.ps1`)

### Parameters

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)
```

### Logging

Use `Write-Log` (not `Write-ColorOutput`):

```powershell
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}
```

### Cleanup Flow

```
1. Test-AzureLogin (using Get-AzContext / Connect-AzAccount)
2. Check resource group exists (Get-AzResourceGroup)
3. List all resources in the group
4. Prompt for confirmation (unless -Force)
5. Remove-AzResourceGroup -Force -AsJob
6. Optional: wait and report duration
```

---

## PowerShell Validate Script (`validate.ps1`)

### Parameters

```powershell
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
```

### Validation Checks

1. **Bicep syntax** — `az bicep build --file $TemplateFile --outdir temp`; clean up temp artifacts.
2. **ARM template validation** — create a temporary resource group, run `az deployment group validate`, then delete the temp RG with `--no-wait`.

### Output

- Use `Write-ColorOutput` with ✅/❌ per test.
- Print summary: `🎉 All validation tests passed!` or `❌ Some validation tests failed`.
- Exit code **0** on success, **1** on failure.

---

## Documentation

### `PROJECT_SUMMARY.md`

Include these sections (in order):

1. **Title** — `# <Project Name> - Project Summary`
2. **📁 File Structure** — tree diagram
3. **📊 Project Overview** — table (Name, Description, Use Case, Complexity ⭐, Deployment Time)
4. **🎯 Key Features** — bulleted ✅ list
5. **🚀 Quick Start Commands** — PowerShell examples
6. **🔧 Technical Specifications** — resource details
7. **🎨 Architecture Diagram** — ASCII box diagram

### `Readme.md`

Include these sections (in order):

1. **Title** with emoji — `# 🏗️ <Project Name>`
2. **🎯 Overview** — 2–3 sentence description
3. **🏛️ Architecture** — ASCII diagram + component list
4. **📋 Features** — bullet list
5. **🔧 Parameters** — markdown table (Name | Type | Default | Description)
6. **🚀 Quick Deploy** — step-by-step CLI commands
7. **🧪 Testing** — how to verify the deployment
8. **💰 Estimated Cost** — monthly cost breakdown
9. **📚 References** — links to Azure docs

### Architecture Diagrams

Use Unicode box-drawing characters:

```
┌─────────────────────────────────────┐
│  Azure Resource Group               │
│  ┌───────────────────────────────┐  │
│  │  Virtual Network (10.0.0.0/16)│  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Subnet (10.0.0.0/24)  │  │  │
│  │  │  ┌───────┐ ┌───────┐   │  │  │
│  │  │  │  VM1  │ │  VM2  │   │  │  │
│  │  │  └───────┘ └───────┘   │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

---

## General Rules

- **Default Azure region**: `southeastasia`
- **No hardcoded credentials** — always use `@secure()` parameters.
- **No hardcoded locations** — always use `param location string = resourceGroup().location`.
- **Always use `az` CLI** for all deployment and resource operations — never use `Az` PowerShell module (`New-AzResourceGroupDeployment`, `New-AzResourceGroup`, etc.) in deploy or validate scripts.
- Cleanup scripts (`cleanup.ps1`) are the **only** exception — they use the `Az` PowerShell module (`Get-AzContext`, `Get-AzResourceGroup`, `Remove-AzResourceGroup`).
- Resource group naming convention: `rg-<project-slug>` (e.g., `rg-simple-linux-vm`, `rg-appgw-lab`).
- Keep all files for a project in **one flat folder** (no nested subfolders for infra).
