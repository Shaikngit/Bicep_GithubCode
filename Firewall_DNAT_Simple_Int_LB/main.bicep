@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Prefix to use for VM names')
param vmNamePrefix string = 'BackendVM'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string

@description('Virtual network address prefix')
param vNetAddressPrefix string = '10.0.0.0/16'

@description('Backend subnet address prefix')
param vNetSubnetAddressPrefix string = '10.0.0.0/24'

@description('Bastion subnet address prefix')
param vNetBastionSubnetAddressPrefix string = '10.0.2.0/24'

@description('Hub VNET address prefix')
param hubVNetAddressPrefix string = '192.168.0.0/16'

@description('Hub VNET subnet prefix')
param hubVNetSubnetPrefix string = '192.168.1.0/24'

@description('Firewall subnet prefix')
param firewallSubnetPrefix string = '192.168.2.0/24'

@description('Private IP address of load balancer')
param lbPrivateIPAddress string = '10.0.0.6'

@description('Specifies whether to use a custom image or a default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

@description('Name of the test VM')
param testVmName string = 'TestVM'

@description('The resource ID of the custom image to use if useCustomImage is true.')
param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'

var useCustomImageBool = useCustomImage == 'Yes' ? true : false 
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

var natGatewayName = 'lb-nat-gateway'
var natGatewayPublicIPAddressName = 'lb-nat-gateway-ip'
var vNetName = 'lb-vnet'
var vNetSubnetName = 'backend-subnet'
var storageAccountType = 'Standard_LRS'
var storageAccountName = uniqueString(resourceGroup().id)
var loadBalancerName = 'internal-lb'
var networkInterfaceName = 'lb-nic'
var numberOfInstances = 2
var lbSkuName = 'Standard'
var bastionName = 'lb-bastion'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionPublicIPAddressName = 'lb-bastion-ip'
var hubVNetName = 'hub-vnet'
var hubVNetSubnetName = 'hub-subnet'
var firewallSubnetName = 'AzureFirewallSubnet'
var peeringName = 'vnet-peering'
var firewallName = 'myFirewall'
var firewallPublicIpName = 'myFirewallPublicIP'
var firewallPolicyName = 'myFirewallPolicy'
var firewallRuleCollectionName = 'DNATRuleCollection'
var firewallRuleName = 'DNATRule'

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
        id: natGatewayPublicIPAddress.id
      }
    ]
  }
}

resource natGatewayPublicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: natGatewayPublicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
  }
}

resource vNetName_bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vNet
  name: bastionSubnetName
  properties: {
    addressPrefix: vNetBastionSubnetAddressPrefix
  }
}

resource vNetName_vNetSubnetName 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vNet
  name: vNetSubnetName
  properties: {
    addressPrefix: vNetSubnetAddressPrefix
    natGateway: {
      id: natGateway.id
    }
  }
}

// Define the  Hub VNET
resource hubVnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: hubVNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: hubVNetSubnetName
        properties: {
          addressPrefix: hubVNetSubnetPrefix
        }
      }
      {
        name: firewallSubnetName
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
    ]
  }
}

// Define VNET peering from LB VNET to Hub VNET
resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: vNet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    }
    dependsOn: [
      vNet
    ]
}

// Define VNET peering from Hub VNET to LB VNET
resource hubVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: hubVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: vNet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubVnet
  ]
}


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
    name: lbSkuName
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, numberOfInstances): {
  name: '${networkInterfaceName}${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vNetName_vNetSubnetName.id
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    loadBalancer
  ]
}]

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        properties: {
          subnet: {
            id: vNetName_vNetSubnetName.id
          }
          privateIPAddress: lbPrivateIPAddress
          privateIPAllocationMethod: 'Static'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool1'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName, 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
        name: 'lbrule'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'lbprobe'
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, numberOfInstances): {
  name: '${vmNamePrefix}${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmNamePrefix}${i}'
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
          id: networkInterface[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for i in range(0, numberOfInstances): {
  parent: vm[i]
  name: 'installcustomscript'
  location: location
  tags: {
    displayName: 'install software for Windows VM'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server'
    }
  }
}]

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
            id: vNetName_vNetSubnetName.id
          }
        }
      }
    ]
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
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

// Define the public IP address for the Azure Firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: firewallPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Define the Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2021-03-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'firewallConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVNetName, firewallSubnetName)
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
}

// Define the Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

// Define the NAT rule collection for the Azure Firewall
resource firewallRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: firewallRuleCollectionName
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: firewallRuleCollectionName
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            name: firewallRuleName
            ruleType: 'NatRule'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              firewallPublicIp.properties.ipAddress
            ]
            destinationPorts: [
              '80'
            ]
            translatedAddress: lbPrivateIPAddress
            translatedPort: '80'
            ipProtocols: [
              'TCP'
            ]
          }
        ]
      }
    ]
  }
}



output location string = location
output name string = loadBalancer.name
output resourceGroupName string = resourceGroup().name
output resourceId string = loadBalancer.id
