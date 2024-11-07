param location string = resourceGroup().location
param firewallName string = 'AzFirewall'
param vnetName string = 'Firewallvnet'
param vnetAddressPrefix string = '10.50.0.0/16'
param subnetName string = 'AzureFirewallSubnet'
param subnetPrefix string = '10.50.1.0/24'
param publicIpName string = 'myFirewallPublicIP'

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
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
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2021-02-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }

}

// generate output of VNET for peering
output vnetId string = vnet.id
output firewallIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress


