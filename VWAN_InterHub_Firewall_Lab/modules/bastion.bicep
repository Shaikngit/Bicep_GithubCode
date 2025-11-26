// =============================================================================
// Azure Bastion Module
// =============================================================================
// Creates Azure Bastion with VNet connected to Virtual Hub for secure VM access

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Bastion configuration object')
param bastionConfig object

@description('Virtual Hub resource ID for connection')
param hubId string

@description('Resource tags')
param tags object = {}

// =============================================================================
// VARIABLES
// =============================================================================

var bastionVnetName = '${bastionConfig.name}-vnet'
var bastionSubnetAddressPrefix = bastionConfig.subnetPrefix
var bastionVnetAddressPrefix = bastionConfig.vnetPrefix

// =============================================================================
// VIRTUAL NETWORK FOR BASTION
// =============================================================================

resource bastionVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: bastionVnetName
  location: bastionConfig.location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        bastionVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
        }
      }
    ]
  }
}

// =============================================================================
// PUBLIC IP FOR BASTION
// =============================================================================

resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${bastionConfig.name}-pip'
  location: bastionConfig.location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// =============================================================================
// AZURE BASTION
// =============================================================================

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionConfig.name
  location: bastionConfig.location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    enableIpConnect: true
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionPublicIP.id
          }
          subnet: {
            id: bastionVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// =============================================================================
// VIRTUAL HUB CONNECTION
// =============================================================================

resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-09-01' = {
  name: '${split(hubId, '/')[8]}/connection-${bastionVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: bastionVnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Bastion resource ID')
output bastionId string = bastion.id

@description('Bastion name')
output bastionName string = bastion.name

@description('Bastion VNet ID')
output bastionVnetId string = bastionVnet.id

@description('Bastion VNet name')
output bastionVnetName string = bastionVnet.name

@description('Bastion public IP')
output bastionPublicIP string = bastionPublicIP.properties.ipAddress

@description('Hub connection ID')
output hubConnectionId string = hubConnection.id
