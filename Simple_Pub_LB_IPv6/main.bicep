@description('The name of the administrator of the new VM. Exclusion list: \'admin\',\'administrator\'')
param adminUsername string

@description('The password for the administrator account of the new VM')
@secure()
param adminPassword string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the test VM')
param testVmName string = 'TestVM'

// Add new parameters
@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string

@description('Specifies whether to use a custom image or a default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

@description('The resource ID of the custom image to use if useCustomImage is true.')
param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'

var useCustomImageBool = useCustomImage == 'Yes' ? true : false 
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

var vnetv4AddressRange = '10.0.0.0/16'
var vnetv6AddressRange = 'ace:cab:deca::/48'
var subnetv4AddressRange = '10.0.0.0/24'
var subnetv6AddressRange = 'ace:cab:deca:deed::/64'
var subnetName = 'DualStackSubnet'
var availabilitySetName = 'myavset'
var numberOfInstances = 2
var vmName = 'DsVM'
var publicipName = 'RDPpublicIp'
var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var imageSku = '2019-Datacenter'

var bastionName = 'lb-bastion'
var vNetBastionSubnetAddressPrefix = '10.0.1.0/24'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionPublicIPAddressName = 'lb-bastion-ip'

//var vNetName = 'lb-vnet'

resource publicip 'Microsoft.Network/publicIPAddresses@2020-07-01' = [
  for i in range(0, numberOfInstances): {
    name: '${publicipName}${i}'
    location: location
    sku: {
      name: 'Standard'
    }
    properties: {
      publicIPAllocationMethod: 'Static'
    }
  }
]

resource lbpublicip 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
  name: 'lbpublicip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'shaiknipv6${uniqueString(resourceGroup().id)}'
    }
  }
}

resource lbpublicip_v6 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
  name: 'lbpublicip-v6'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
    dnsSettings: {
      domainNameLabel: 'shaiknipv6${uniqueString(resourceGroup().id)}'
    }
  }
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2020-12-01' = {
  name: availabilitySetName
  location: location
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
  sku: {
    name: 'Aligned'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-07-01' = {
  name: 'loadBalancer'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LBFE'
        properties: {
          publicIPAddress: {
            id: lbpublicip.id
          }
        }
      }
      {
        name: 'LBFE-v6'
        properties: {
          publicIPAddress: {
            id: lbpublicip_v6.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LBBAP'
      }
      {
        name: 'LBBAP-v6'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', 'loadBalancer', 'LBFE')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'loadBalancer', 'LBBAP')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'loadBalancer', 'IPv4IPv6probe')
          }
        }
        name: 'lbrule'
      }
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', 'loadBalancer', 'LBFE-v6')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'loadBalancer', 'LBBAP-v6')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'loadBalancer', 'IPv4IPv6probe')
          }
        }
        name: 'lbrule-v6'
      }
    ]
    probes: [
      {
        name: 'IPv4IPv6probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource VNET 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: 'VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetv4AddressRange
        vnetv6AddressRange
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: [
            subnetv4AddressRange
            subnetv6AddressRange
          ]
        }
      }
    ]
  }
}

resource dsNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: 'dsNsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-HTTP-in'
        properties: {
          description: 'Allow HTTP'
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-all-out'
        properties: {
          description: 'Allow out All'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1002
          direction: 'Outbound'
        }
      }
      {
        name: 'allow-RDP-in'
        properties: {
          description: 'Allow RDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1003
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-MyIpv6App-out'
        properties: {
          description: 'Allow My IPv6 App'
          protocol: 'Tcp'
          sourcePortRange: '33819-33829'
          destinationPortRange: '5000-6000'
          sourceAddressPrefix: 'ace:cab:deca:deed::/64'
          destinationAddressPrefixes: [
            'cab:cab:aaaa:bbbb::/64'
            'cab:cab:1111:2222::/64'
          ]
          access: 'Allow'
          priority: 1004
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Network/networkInterfaces@2020-07-01' = [
  for i in range(0, numberOfInstances): {
    name: '${vmName}${i}'
    location: location
    properties: {
      networkSecurityGroup: {
        id: dsNsg.id
      }
      ipConfigurations: [
        {
          name: 'ipconfig-v4'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            privateIPAddressVersion: 'IPv4'
            primary: true
            publicIPAddress: {
              id: resourceId('Microsoft.Network/publicIPAddresses', '${publicipName}${i}')
            }
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VNET', subnetName)
            }
            loadBalancerBackendAddressPools: [
              {
                id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'loadBalancer', 'LBBAP')
              }
            ]
          }
        }
        {
          name: 'ipconfig-v6'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            privateIPAddressVersion: 'IPv6'
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VNET', subnetName)
            }
            loadBalancerBackendAddressPools: [
              {
                id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'loadBalancer', 'LBBAP-v6')
              }
            ]
          }
        }
      ]
    }
    dependsOn: [
      VNET
      loadBalancer
      publicip
    ]
  }
]

resource Microsoft_Compute_virtualMachines_vm 'Microsoft.Compute/virtualMachines@2020-12-01' = [
  for i in range(0, numberOfInstances): {
    name: '${vmName}${i}'
    location: location
    properties: {
      availabilitySet: {
        id: availabilitySet.id
      }
      hardwareProfile: {
        vmSize: vmSize
      }
      osProfile: {
        computerName: '${vmName}${i}'
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      storageProfile: {
        imageReference: useCustomImageBool ? {
          id: customImageResourceId
        } : {
          publisher: imagePublisher
          offer: imageOffer
          sku: imageSku
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: resourceId('Microsoft.Network/networkInterfaces', '${vmName}${i}')
          }
        ]
      }
    }
    dependsOn: [
      vm
    ]
  }
]

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for i in range(0, numberOfInstances): {
  parent: Microsoft_Compute_virtualMachines_vm[i]
  name: 'installIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
    }
  }
}]

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIPAddress.id
          }
          subnet: {
            id: vNetName_bastionSubnet.id
          }
        }
      }
    ]
  }
}

resource bastionPublicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: bastionPublicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource testVmNetworkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${testVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VNET', subnetName)
          }
        }
      }
      {
        name: 'ipconfig-v6'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv6'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', '${testVmName}-public-ipv6')
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'VNET', subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    VNET
    testVmPublicIPv6
  ]
}

resource testVmPublicIPv6 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${testVmName}-public-ipv6'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv6'
    publicIPAllocationMethod: 'Static'
  }
}

resource testVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: testVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: testVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: useCustomImageBool ? {
        id: customImageResourceId
      } : {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testVmNetworkInterface.id
        }
      ]
    }
  }
}

resource vNetName_bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: VNET
  name: bastionSubnetName
  properties: {
    addressPrefix: vNetBastionSubnetAddressPrefix
  }
}


