// =============================================================================
// Azure Firewall Module for Virtual Hub
// =============================================================================
// Creates Azure Firewall in Virtual Hub (Secured Hub) configuration

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Azure Firewall name')
param firewallName string

@description('Virtual Hub resource ID')
param hubId string

@description('Hub configuration object') 
param hubConfig object

@description('Azure Firewall configuration')
param firewallConfig object

@description('Resource tags')
param tags object = {}

// =============================================================================
// AZURE FIREWALL POLICY
// =============================================================================

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
  name: '${firewallName}-policy'
  location: hubConfig.location
  tags: tags
  properties: {
    sku: {
      tier: firewallConfig.sku.tier
    }
    threatIntelMode: firewallConfig.threatIntelMode
    dnsSettings: firewallConfig.dnsSettings
    // Note: intrusionDetection is only available in Premium tier
    // Removed for Standard tier compatibility
  }
}

resource firewallPolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowInterHubTraffic'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAllInterHubTraffic'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowSSHRDP'
        priority: 110
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowSSH'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '22'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowRDP'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '3389'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowICMP'
            ipProtocols: [
              'ICMP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

// =============================================================================
// AZURE FIREWALL
// =============================================================================

resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: firewallName
  location: hubConfig.location
  tags: tags
  properties: {
    sku: firewallConfig.sku
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: hubId
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  dependsOn: [
    firewallPolicyRuleCollectionGroup
  ]
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Azure Firewall resource ID')
output firewallId string = azureFirewall.id

@description('Azure Firewall name')
output firewallName string = azureFirewall.name

@description('Azure Firewall private IP address')
output firewallPrivateIP string = azureFirewall.properties.hubIPAddresses.privateIPAddress

@description('Azure Firewall policy ID')
output firewallPolicyId string = firewallPolicy.id

@description('Azure Firewall properties')
output firewallProperties object = azureFirewall.properties
