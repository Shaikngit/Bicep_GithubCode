@description('Username for both Linux virtual machines.')
param adminUsername string

@description('Password or SSH public key for both Linux virtual machines, based on authenticationType.')
@secure()
param adminPasswordOrKey string

@description('Authentication type for Linux VMs.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Prefix used for naming resources.')
param resourcePrefix string = 'crpeer'

@description('The Ubuntu version for the VM. This picks a fully patched image.')
@allowed([
  'Ubuntu-2004'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'Ubuntu-2204'

@description('Address space for EastUS2 VNet.')
param eastVnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet prefix for EastUS2 workload subnet.')
param eastSubnetAddressPrefix string = '10.10.1.0/24'

@description('Address space for WestUS2 VNet.')
param westVnetAddressPrefix string = '10.20.0.0/16'

@description('Subnet prefix for WestUS2 workload subnet.')
param westSubnetAddressPrefix string = '10.20.1.0/24'

@description('Primary region for the first VNet/VM.')
param eastRegion string = 'eastus2'

@description('Secondary region for the second VNet/VM.')
param westRegion string = 'westus2'

var vmSize = 'Standard_D2s_v5'

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

var eastNsgName = '${resourcePrefix}-nsg-east'
var westNsgName = '${resourcePrefix}-nsg-west'
var eastVnetName = '${resourcePrefix}-vnet-east'
var westVnetName = '${resourcePrefix}-vnet-west'
var eastVmName = '${resourcePrefix}-vm-east'
var westVmName = '${resourcePrefix}-vm-west'
var eastNicName = '${resourcePrefix}-nic-east'
var westNicName = '${resourcePrefix}-nic-west'
var eastBastionPipName = '${resourcePrefix}-bastion-pip-east'
var westBastionPipName = '${resourcePrefix}-bastion-pip-west'
var eastBastionName = '${resourcePrefix}-bastion-east'
var westBastionName = '${resourcePrefix}-bastion-west'
var eastToWestPeeringName = '${eastVnetName}-to-${westVnetName}'
var westToEastPeeringName = '${westVnetName}-to-${eastVnetName}'

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

resource eastNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: eastNsgName
  location: eastRegion
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: eastVnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-Peer-VNet-Inbound'
        properties: {
          priority: 210
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: westVnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: {
    displayName: eastNsgName
  }
}

resource westNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: westNsgName
  location: westRegion
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-VNet-Inbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: westVnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-Peer-VNet-Inbound'
        properties: {
          priority: 210
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: eastVnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
  tags: {
    displayName: westNsgName
  }
}

resource eastVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: eastVnetName
  location: eastRegion
  properties: {
    addressSpace: {
      addressPrefixes: [
        eastVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'workload-subnet'
        properties: {
          addressPrefix: eastSubnetAddressPrefix
          networkSecurityGroup: {
            id: eastNetworkSecurityGroup.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.2.0/26'
        }
      }
    ]
  }
  tags: {
    displayName: eastVnetName
  }
}

resource westVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: westVnetName
  location: westRegion
  properties: {
    addressSpace: {
      addressPrefixes: [
        westVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'workload-subnet'
        properties: {
          addressPrefix: westSubnetAddressPrefix
          networkSecurityGroup: {
            id: westNetworkSecurityGroup.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.20.2.0/26'
        }
      }
    ]
  }
  tags: {
    displayName: westVnetName
  }
}

resource eastBastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: eastBastionPipName
  location: eastRegion
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource westBastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: westBastionPipName
  location: westRegion
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource eastBastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: eastBastionName
  location: eastRegion
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: eastBastionPublicIp.id
          }
          subnet: {
            id: eastVirtualNetwork.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource westBastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: westBastionName
  location: westRegion
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: westBastionPublicIp.id
          }
          subnet: {
            id: westVirtualNetwork.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource eastNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: eastNicName
  location: eastRegion
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: eastVirtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
  tags: {
    displayName: eastNicName
  }
}

resource westNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: westNicName
  location: westRegion
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: westVirtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
  tags: {
    displayName: westNicName
  }
}

resource eastVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: eastVmName
  location: eastRegion
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: eastVmName
      adminUsername: adminUsername
      adminPassword: authenticationType == 'password' ? adminPasswordOrKey : null
      linuxConfiguration: authenticationType == 'sshPublicKey' ? linuxConfiguration : null
    }
    storageProfile: {
      imageReference: imageReference[ubuntuOSVersion]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: eastNic.id
        }
      ]
    }
  }
  tags: {
    displayName: eastVmName
  }
}

resource westVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: westVmName
  location: westRegion
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: westVmName
      adminUsername: adminUsername
      adminPassword: authenticationType == 'password' ? adminPasswordOrKey : null
      linuxConfiguration: authenticationType == 'sshPublicKey' ? linuxConfiguration : null
    }
    storageProfile: {
      imageReference: imageReference[ubuntuOSVersion]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: westNic.id
        }
      ]
    }
  }
  tags: {
    displayName: westVmName
  }
}

resource eastToWestPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: eastVirtualNetwork
  name: eastToWestPeeringName
  properties: {
    remoteVirtualNetwork: {
      id: westVirtualNetwork.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource westToEastPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: westVirtualNetwork
  name: westToEastPeeringName
  properties: {
    remoteVirtualNetwork: {
      id: eastVirtualNetwork.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

output eastVmName string = eastVm.name
output westVmName string = westVm.name
output eastVmPrivateIp string = eastNic.properties.ipConfigurations[0].properties.privateIPAddress
output westVmPrivateIp string = westNic.properties.ipConfigurations[0].properties.privateIPAddress
output eastBastionName string = eastBastionHost.name
output westBastionName string = westBastionHost.name
output eastRegionName string = eastRegion
output westRegionName string = westRegion
output vmSizeUsed string = vmSize
output connectivityTestCommandFromEast string = 'ping -c 4 ${westNic.properties.ipConfigurations[0].properties.privateIPAddress}'
output connectivityTestCommandFromWest string = 'ping -c 4 ${eastNic.properties.ipConfigurations[0].properties.privateIPAddress}'
