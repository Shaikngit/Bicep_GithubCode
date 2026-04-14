# Bicep Conventions (`main.bicep`)

## Parameter Ordering & Style

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

## Variable Patterns

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

## Resource Declaration Order

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

## Resource Naming & API Versions

- Use recent stable API versions (prefer `@2023-09-01` for networking, `@2023-09-01` for compute).
- Symbolic resource names use **camelCase** without the provider prefix (e.g., `resource virtualNetwork`, `resource networkSecurityGroup`).
- Use `location: location` on every resource (never hard-code a region). Exception: Private DNS zones use `location: 'global'`.

## Network Addressing Standards

| Purpose | CIDR |
|---------|------|
| VNet address space | `10.x.0.0/16` |
| Regular subnets | `/24` |
| Bastion subnet (`AzureBastionSubnet`) | `/26` or larger |
| Firewall subnet (`AzureFirewallSubnet`) | `/24` |

- Use **reserved subnet names** for Azure services: `AzureBastionSubnet`, `AzureFirewallSubnet`.
- For Private Link scenarios, set `privateLinkServiceNetworkPolicies: 'Disabled'` on the service subnet.

## NSG Rules

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

## VM Configuration

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

## Dependencies

- Prefer **implicit** dependencies (reference another resource's `.id` or `.properties`).
- Use explicit `dependsOn` only when no property reference creates the dependency (e.g., loop-based resources).

## Outputs

Provide helpful outputs at the bottom of the file:

```bicep
output adminUsername string = adminUsername
output hostname string = publicIPAddress.properties.dnsSettings.fqdn
output sshCommand string = 'ssh ${adminUsername}@${publicIPAddress.properties.dnsSettings.fqdn}'
```

## Tags

Add `tags` with a `displayName` on resources where useful:

```bicep
tags: {
  displayName: networkInterfaceName
}
```
