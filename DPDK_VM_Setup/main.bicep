@description('The username for the virtual machine administrator.')
param adminUsername string

@description('The password for the virtual machine administrator.')
@secure()
param adminPassword string

@description('The location for all resources.')
param location string = 'southeastasia'

@description('Select the hardware type for DPDK testing')
@allowed([
  'MANA'
  'Mellanox'
])
param hardwareType string = 'MANA'

// Automatically select the appropriate VM size based on hardware type
var vmSize = hardwareType == 'MANA' ? 'Standard_D8s_v6' : 'Standard_D8s_v5'
var vmNamePrefix = hardwareType == 'MANA' ? 'manavm' : 'dpdkvm'

// Virtual Network for DPDK testing
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'dpdk-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'dpdk-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Network Security Group - Allow SSH and internal traffic
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'dpdk-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'AllowAllInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Public IPs for direct SSH access
resource vm1PublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${vmNamePrefix}1-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vm2PublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${vmNamePrefix}2-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// VM1 Management NIC (eth0) - NO accelerated networking for SSH safety
resource nic1mgmt 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmNamePrefix}1-mgmt-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.10'
          publicIPAddress: {
            id: vm1PublicIp.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: false  // Management NIC - keep SSH safe
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM1 DPDK NIC (eth1) - Accelerated Networking ENABLED for DPDK
resource nic1dpdk 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmNamePrefix}1-dpdk-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.20'
        }
      }
    ]
    enableAcceleratedNetworking: true  // DPDK NIC - accelerated networking
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM2 Management NIC (eth0) - NO accelerated networking for SSH safety
resource nic2mgmt 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmNamePrefix}2-mgmt-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.11'
          publicIPAddress: {
            id: vm2PublicIp.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: false  // Management NIC - keep SSH safe
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM2 DPDK NIC (eth1) - Accelerated Networking ENABLED for DPDK
resource nic2dpdk 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmNamePrefix}2-dpdk-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.21'
        }
      }
    ]
    enableAcceleratedNetworking: true  // DPDK NIC - accelerated networking
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// VM1 - Ubuntu 22.04 LTS for DPDK
resource vm1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${vmNamePrefix}1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}1'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmNamePrefix}1-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1mgmt.id
          properties: {
            primary: true
          }
        }
        {
          id: nic1dpdk.id
          properties: {
            primary: false
          }
        }
      ]
    }
  }
}

// VM2 - Ubuntu 22.04 LTS for DPDK
resource vm2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${vmNamePrefix}2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}2'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmNamePrefix}2-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2mgmt.id
          properties: {
            primary: true
          }
        }
        {
          id: nic2dpdk.id
          properties: {
            primary: false
          }
        }
      ]
    }
  }
}

// Outputs
output vm1Name string = vm1.name
output vm1PublicIP string = vm1PublicIp.properties.ipAddress
output vm1MgmtIP string = nic1mgmt.properties.ipConfigurations[0].properties.privateIPAddress
output vm1DpdkIP string = nic1dpdk.properties.ipConfigurations[0].properties.privateIPAddress
output vm2Name string = vm2.name
output vm2PublicIP string = vm2PublicIp.properties.ipAddress
output vm2MgmtIP string = nic2mgmt.properties.ipConfigurations[0].properties.privateIPAddress
output vm2DpdkIP string = nic2dpdk.properties.ipConfigurations[0].properties.privateIPAddress
output vnetName string = vnet.name
output subnetName string = vnet.properties.subnets[0].name
output vm1DpdkNicAccelNet bool = nic1dpdk.properties.enableAcceleratedNetworking
output vm2DpdkNicAccelNet bool = nic2dpdk.properties.enableAcceleratedNetworking
