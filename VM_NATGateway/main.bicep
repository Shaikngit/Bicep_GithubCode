// ============================================================================
// VM_NATGateway — Bicep Template
// Deploys a Linux VM behind a NAT Gateway for outbound internet access
// ============================================================================

// --- Authentication ---
@description('Administrator username for the Virtual Machine.')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

// --- Resource Naming ---
@description('Name of the virtual machine.')
param vmName string = 'natgwVM'

@description('Name of the virtual network.')
param virtualNetworkName string = 'vNet'

@description('Name of the subnet.')
param subnetName string = 'Subnet'

@description('Name of the network security group.')
param networkSecurityGroupName string = 'SecGroupNet'

@description('Name of the NAT Gateway.')
param natGatewayName string = 'natGateway'

@description('Name of the NAT Gateway public IP.')
param natGatewayPublicIPName string = 'natGatewayPublicIP'

// --- Size / SKU ---
@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string = 'Non-Overlake'

@description('The Ubuntu version for the VM.')
@allowed([
  'Ubuntu-2004'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'Ubuntu-2204'

@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

// --- Network Addressing ---
@description('Virtual network address prefix.')
param vNetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix.')
param vNetSubnetAddressPrefix string = '10.0.0.0/24'

// --- Location (always last) ---
@description('Azure region for all resources.')
param location string = resourceGroup().location

// ============================================================================
// Variables
// ============================================================================
var networkInterfaceName = '${vmName}NetInt'
var osDiskType = 'Standard_LRS'
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

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
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}

var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.LinuxAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
var maaEndpoint = substring('emptystring', 0, 0)

// ============================================================================
// Resources (order: NSG → VNet → PIP → NAT Gateway → NIC → VM → Extensions)
// ============================================================================

// 1. Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// 2. Virtual Network + Subnet (with NAT Gateway association)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: vNetSubnetAddressPrefix
          networkSecurityGroup: { id: networkSecurityGroup.id }
          natGateway: { id: natGateway.id }
        }
      }
    ]
  }
}

// 3. Public IP for NAT Gateway (Standard SKU, Static)
resource natGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: natGatewayPublicIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  tags: {
    displayName: natGatewayPublicIPName
  }
}

// 4. NAT Gateway
resource natGateway 'Microsoft.Network/natGateways@2023-09-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGatewayPublicIP.id
      }
    ]
  }
  tags: {
    displayName: natGatewayName
  }
}

// 5. Network Interface (no public IP — outbound via NAT Gateway)
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: {
    displayName: networkInterfaceName
  }
}

// 6. Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: imageReference[ubuntuOSVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: (securityType == 'TrustedLaunch') ? securityProfileJson : null
  }
  tags: {
    displayName: vmName
  }
}

// 7. VM Extension — Guest Attestation (Trusted Launch only)
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (securityType == 'TrustedLaunch' && securityProfileJson.uefiSettings.secureBootEnabled && securityProfileJson.uefiSettings.vTpmEnabled) {
  parent: vm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
output adminUsername string = adminUsername
output vmName string = vm.name
output vmId string = vm.id
output vmPrivateIP string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output vnetId string = virtualNetwork.id
output natGatewayPublicIP string = natGatewayPublicIP.properties.ipAddress
output natGatewayName string = natGateway.name
