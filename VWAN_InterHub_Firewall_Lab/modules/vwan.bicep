// =============================================================================
// Virtual WAN Module
// =============================================================================
// Creates a Virtual WAN resource with standard configuration

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Virtual WAN configuration object')
param vwanConfig object

@description('Deployment location')
param location string

@description('Resource tags')
param tags object = {}

// =============================================================================
// VIRTUAL WAN RESOURCE
// =============================================================================

resource virtualWan 'Microsoft.Network/virtualWans@2023-09-01' = {
  name: vwanConfig.name
  location: location
  tags: tags
  properties: {
    allowBranchToBranchTraffic: vwanConfig.allowBranchToBranchTraffic
    allowVnetToVnetTraffic: vwanConfig.allowVnetToVnetTraffic
    type: vwanConfig.type
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Virtual WAN resource ID')
output virtualWanId string = virtualWan.id

@description('Virtual WAN name')
output virtualWanName string = virtualWan.name

@description('Virtual WAN properties')
output virtualWanProperties object = virtualWan.properties
