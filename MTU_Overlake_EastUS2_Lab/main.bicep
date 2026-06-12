targetScope = 'resourceGroup'

@description('Azure region for all resources. Keep this as eastus2 for this lab.')
param location string = resourceGroup().location

@description('Administrator username for both Linux VMs.')
param adminUsername string = 'azureuser'

@description('Administrator password for both Linux VMs.')
@secure()
param adminPassword string

@description('Virtual machine size. Keep an accelerated networking capable SKU.')
param vmSize string = 'Standard_D4s_v5'

@description('Virtual network name.')
param virtualNetworkName string = 'vnet-mtu-lab'

@description('Subnet name.')
param subnetName string = 'subnet-lab'

@description('Address space for the virtual network.')
param vnetAddressPrefix string = '10.235.0.0/16'

@description('Address prefix for the subnet.')
param subnetAddressPrefix string = '10.235.1.0/24'

@description('Name of the source VM with public IP.')
param sourceVmName string = 'vm-mtu-src'

@description('Name of the destination VM without public IP.')
param destinationVmName string = 'vm-mtu-dst'

@description('Name of the network security group.')
param networkSecurityGroupName string = 'nsg-mtu-lab'

@description('Name of the source network interface.')
param sourceNicName string = 'nic-mtu-src'

@description('Name of the destination network interface.')
param destinationNicName string = 'nic-mtu-dst'

@description('Name of the source VM public IP.')
param sourcePublicIpName string = 'pip-mtu-src'

@description('VM image publisher.')
param imagePublisher string = 'Canonical'

@description('VM image offer.')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('VM image SKU.')
param imageSku string = '22_04-lts-gen2'

@description('VM image version.')
param imageVersion string = 'latest'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow SSH'
        }
      }
      {
        name: 'allow-icmp'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Icmp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow ICMP'
        }
      }
      {
        name: 'allow-iperf3'
        properties: {
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5201'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow iperf3 TCP port 5201'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource sourcePublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: sourcePublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource sourceNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: sourceNicName
  location: location
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: sourcePublicIp.id
          }
        }
      }
    ]
  }
}

resource destinationNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: destinationNicName
  location: location
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource sourceVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: sourceVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: sourceVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: sourceNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource destinationVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: destinationVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: destinationVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: destinationNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output sourceVmPublicIp string = sourcePublicIp.properties.ipAddress
output sourceVmPrivateIp string = sourceNic.properties.ipConfigurations[0].properties.privateIPAddress
output destinationVmPrivateIp string = destinationNic.properties.ipConfigurations[0].properties.privateIPAddress
output sourceNicOutputName string = sourceNic.name
output destinationNicOutputName string = destinationNic.name
