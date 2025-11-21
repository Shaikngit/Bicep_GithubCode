// =============================================================================
// Virtual Hub Module
// =============================================================================
// Creates a Virtual Hub for Virtual WAN with specified configuration

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Hub configuration object')
param hubConfig object

@description('Virtual WAN resource ID')
param virtualWanId string

@description('Resource tags')
param tags object = {}

// =============================================================================
// VIRTUAL HUB RESOURCE
// =============================================================================

resource virtualHub 'Microsoft.Network/virtualHubs@2023-09-01' = {
  name: hubConfig.name
  location: hubConfig.location
  tags: tags
  properties: {
    virtualWan: {
      id: virtualWanId
    }
    addressPrefix: hubConfig.addressPrefix
    sku: 'Standard'
    hubRoutingPreference: hubConfig.hubRouting.preferredRoutingGateway
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Virtual Hub resource ID')
output hubId string = virtualHub.id

@description('Virtual Hub name')
output hubName string = virtualHub.name

@description('Virtual Hub location')
output hubLocation string = virtualHub.location

@description('Virtual Hub address prefix')
output hubAddressPrefix string = virtualHub.properties.addressPrefix

@description('Virtual Hub properties')
output hubProperties object = virtualHub.properties
