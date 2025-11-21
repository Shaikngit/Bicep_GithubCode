// =============================================================================
// Routing Intent Module
// =============================================================================
// Creates routing intent policies for Virtual Hub with Azure Firewall

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Virtual Hub resource ID')
param hubId string

@description('Azure Firewall resource ID')
param firewallId string

// Hub name is extracted from hubId resource path

// =============================================================================
// ROUTING INTENT
// =============================================================================

resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2023-09-01' = {
  name: '${split(hubId, '/')[8]}/routingIntent'
  properties: {
    routingPolicies: [
      {
        name: 'PrivateTrafficPolicy'
        destinations: [
          'PrivateTraffic'
        ]
        nextHop: firewallId
      }
    ]
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Routing Intent resource ID')
output routingIntentId string = routingIntent.id

@description('Routing Intent name')
output routingIntentName string = routingIntent.name
