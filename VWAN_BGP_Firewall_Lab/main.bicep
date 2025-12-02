// ============================================================================
// Virtual WAN Topology with BGP over IPsec, Azure Firewall (Non-Secure Hub)
// ============================================================================
// This template deploys:
// 1. Virtual WAN + Virtual Hub (Southeast Asia) with VPN Gateway and Azure Firewall
// 2. Two Spoke VNets connected to vHub (Southeast Asia)
// 3. Simulated On-Prem VNet with VPN Gateway (East Asia)
// 4. BGP over IPsec VPN connection between On-Prem and vHub
// 5. Azure Bastion for VM connectivity testing
// 6. Test VMs in spokes and on-prem
//
// NOTE: This deployment does NOT use:
// - Secure Hub
// - Routing Intent / Routing Policy
// - Route Maps
// - UDRs
// Only default vWAN routing behavior is used.
// ============================================================================

// Parameters
// ============================================================================

@description('Location for Virtual WAN, Hub, and Spoke resources')
param vwanLocation string = 'southeastasia'

@description('Location for simulated on-premises resources')
param onPremLocation string = 'eastasia'

@description('Admin username for VMs')
param adminUsername string = 'azureadmin'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Shared key for VPN connections')
@secure()
param vpnSharedKey string

@description('Deployment prefix for naming resources')
param deploymentPrefix string = 'vwan-bgp'

// ============================================================================
// Address Space Configuration - Adjust as needed
// ============================================================================

// Virtual Hub address prefix
var hubAddressPrefix = '10.10.0.0/24'

// Spoke VNet address spaces
var spoke1AddressPrefix = '10.20.0.0/16'
var spoke1SubnetPrefix = '10.20.1.0/24'
var spoke1BastionSubnetPrefix = '10.20.255.0/26'

var spoke2AddressPrefix = '10.30.0.0/16'
var spoke2SubnetPrefix = '10.30.1.0/24'

// On-Prem VNet address spaces
var onPremAddressPrefix = '192.168.0.0/16'
var onPremGatewaySubnetPrefix = '192.168.1.0/24'
var onPremVmSubnetPrefix = '192.168.2.0/24'
var onPremBastionSubnetPrefix = '192.168.255.0/26'

// BGP Configuration
var onPremAsn = 65010
var vwanHubAsn = 65515 // Default vWAN ASN

// VM Configuration
var vmSize = 'Standard_B2ms'
var vmImagePublisher = 'MicrosoftWindowsServer'
var vmImageOffer = 'WindowsServer'
var vmImageSku = '2022-datacenter-azure-edition'

// ============================================================================
// Virtual WAN and Virtual Hub
// ============================================================================

@description('Virtual WAN resource')
resource virtualWan 'Microsoft.Network/virtualWans@2023-11-01' = {
  name: '${deploymentPrefix}-vwan'
  location: vwanLocation
  properties: {
    type: 'Standard'
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
  }
}

@description('Virtual Hub in Southeast Asia')
resource virtualHub 'Microsoft.Network/virtualHubs@2023-11-01' = {
  name: '${deploymentPrefix}-hub-sea'
  location: vwanLocation
  properties: {
    virtualWan: {
      id: virtualWan.id
    }
    addressPrefix: hubAddressPrefix
    sku: 'Standard'
    // No routing intent or secure hub configuration
  }
}

// ============================================================================
// Hub VPN Gateway (for site-to-site connections)
// ============================================================================

@description('VPN Gateway in Virtual Hub')
resource hubVpnGateway 'Microsoft.Network/vpnGateways@2023-11-01' = {
  name: '${deploymentPrefix}-hub-vpngw'
  location: vwanLocation
  properties: {
    virtualHub: {
      id: virtualHub.id
    }
    vpnGatewayScaleUnit: 1
    bgpSettings: {
      asn: vwanHubAsn
    }
  }
}

// ============================================================================
// Azure Firewall in Virtual Hub (Non-Secure Hub deployment)
// ============================================================================

@description('Azure Firewall Policy')
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: '${deploymentPrefix}-fw-policy'
  location: vwanLocation
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

@description('Firewall Policy Rule Collection Group - Allow all for testing')
resource firewallPolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowAllNetworkRules'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAllTraffic'
            description: 'Allow all traffic for testing - restrict in production'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowICMP'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowICMPPing'
            description: 'Allow ICMP for connectivity testing'
            sourceAddresses: [
              '10.0.0.0/8'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              '10.0.0.0/8'
              '192.168.0.0/16'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'ICMP'
            ]
          }
        ]
      }
    ]
  }
}

@description('Azure Firewall in Virtual Hub')
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: '${deploymentPrefix}-hub-fw'
  location: vwanLocation
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    virtualHub: {
      id: virtualHub.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  dependsOn: [
    hubVpnGateway // Ensure VPN Gateway is deployed first
  ]
}

// ============================================================================
// Spoke VNets (Southeast Asia)
// ============================================================================

@description('Spoke 1 Virtual Network')
resource vnetSpoke1 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${deploymentPrefix}-vnet-spoke1'
  location: vwanLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke1AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: spoke1SubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: spoke1BastionSubnetPrefix
        }
      }
    ]
  }
}

@description('Spoke 2 Virtual Network')
resource vnetSpoke2 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${deploymentPrefix}-vnet-spoke2'
  location: vwanLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke2AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: spoke2SubnetPrefix
        }
      }
    ]
  }
}

// ============================================================================
// Virtual Hub Connections (Spoke to Hub)
// ============================================================================

@description('Hub Connection for Spoke 1')
resource hubConnectionSpoke1 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: virtualHub
  name: 'conn-spoke1'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpoke1.id
    }
    enableInternetSecurity: false
    // Default route propagation - no custom routing tables or UDRs
    routingConfiguration: {
      associatedRouteTable: {
        id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
        labels: [
          'default'
        ]
      }
    }
  }
  dependsOn: [
    hubVpnGateway
    azureFirewall
  ]
}

@description('Hub Connection for Spoke 2')
resource hubConnectionSpoke2 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: virtualHub
  name: 'conn-spoke2'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpoke2.id
    }
    enableInternetSecurity: false
    // Default route propagation - no custom routing tables or UDRs
    routingConfiguration: {
      associatedRouteTable: {
        id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
        labels: [
          'default'
        ]
      }
    }
  }
  dependsOn: [
    hubVpnGateway
    azureFirewall
    hubConnectionSpoke1
  ]
}

// ============================================================================
// Simulated On-Premises VNet (East Asia)
// ============================================================================

@description('On-Premises Virtual Network (simulated)')
resource vnetOnPrem 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${deploymentPrefix}-vnet-onprem'
  location: onPremLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        onPremAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: onPremGatewaySubnetPrefix
        }
      }
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: onPremVmSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: onPremBastionSubnetPrefix
        }
      }
    ]
  }
}

// ============================================================================
// On-Premises VPN Gateway
// ============================================================================

@description('Public IP for On-Prem VPN Gateway')
resource onPremVpnGatewayPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${deploymentPrefix}-onprem-vpngw-pip'
  location: onPremLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('On-Premises VPN Gateway with BGP')
resource onPremVpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: '${deploymentPrefix}-onprem-vpngw'
  location: onPremLocation
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation2'
    sku: {
      name: 'VpnGw2'
      tier: 'VpnGw2'
    }
    enableBgp: true
    bgpSettings: {
      asn: onPremAsn
      // BGP peering address will be automatically assigned from GatewaySubnet
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: onPremVpnGatewayPip.id
          }
          subnet: {
            id: '${vnetOnPrem.id}/subnets/GatewaySubnet'
          }
        }
      }
    ]
  }
}

// ============================================================================
// vWAN VPN Site (representing On-Premises)
// ============================================================================

@description('VPN Site representing On-Premises network')
resource vpnSite 'Microsoft.Network/vpnSites@2023-11-01' = {
  name: '${deploymentPrefix}-vpnsite-onprem'
  location: vwanLocation
  properties: {
    virtualWan: {
      id: virtualWan.id
    }
    deviceProperties: {
      deviceVendor: 'Microsoft'
      deviceModel: 'Azure VPN Gateway'
      linkSpeedInMbps: 100
    }
    addressSpace: {
      addressPrefixes: [
        onPremAddressPrefix
      ]
    }
    // BGP properties are now configured in vpnSiteLinks (root-level bgpProperties is deprecated)
    vpnSiteLinks: [
      {
        name: 'link-onprem'
        properties: {
          ipAddress: onPremVpnGatewayPip.properties.ipAddress
          linkProperties: {
            linkProviderName: 'Azure'
            linkSpeedInMbps: 100
          }
          bgpProperties: {
            asn: onPremAsn
            bgpPeeringAddress: onPremVpnGateway.properties.bgpSettings.bgpPeeringAddress
          }
        }
      }
    ]
  }
}

// ============================================================================
// vHub VPN Site Connection (IPsec + BGP)
// ============================================================================

@description('VPN Connection from Hub to On-Prem Site')
resource vpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2023-11-01' = {
  parent: hubVpnGateway
  name: 'conn-to-onprem'
  properties: {
    remoteVpnSite: {
      id: vpnSite.id
    }
    // enableBgp is now configured in vpnLinkConnections (root-level enableBgp is deprecated)
    enableInternetSecurity: false
    // Default vWAN propagation - no custom routes
    routingConfiguration: {
      associatedRouteTable: {
        id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
        labels: [
          'default'
        ]
      }
    }
    vpnLinkConnections: [
      {
        name: 'link-onprem'
        properties: {
          vpnSiteLink: {
            id: '${vpnSite.id}/vpnSiteLinks/link-onprem'
          }
          sharedKey: vpnSharedKey
          enableBgp: true
          vpnConnectionProtocolType: 'IKEv2'
          connectionBandwidth: 100
          usePolicyBasedTrafficSelectors: false
        }
      }
    ]
  }
}

// ============================================================================
// Local Network Gateway (On-Prem side - represents vHub)
// ============================================================================

@description('Local Network Gateway representing vHub VPN Gateway')
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: '${deploymentPrefix}-lng-vhub'
  location: onPremLocation
  properties: {
    gatewayIpAddress: hubVpnGateway.properties.ipConfigurations[0].publicIpAddress
    bgpSettings: {
      asn: vwanHubAsn
      bgpPeeringAddress: hubVpnGateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
    }
  }
}

@description('VPN Connection from On-Prem Gateway to vHub')
resource onPremToHubConnection 'Microsoft.Network/connections@2023-11-01' = {
  name: '${deploymentPrefix}-conn-onprem-to-hub'
  location: onPremLocation
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: onPremVpnGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: localNetworkGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    enableBgp: true
    connectionProtocol: 'IKEv2'
    usePolicyBasedTrafficSelectors: false
  }
}

// ============================================================================
// Azure Bastion (for testing connectivity)
// ============================================================================

@description('Public IP for Azure Bastion in Spoke 1')
resource bastionSpoke1Pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${deploymentPrefix}-bastion-spoke1-pip'
  location: vwanLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Azure Bastion in Spoke 1 for testing')
resource bastionSpoke1 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: '${deploymentPrefix}-bastion-spoke1'
  location: vwanLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionSpoke1Pip.id
          }
          subnet: {
            id: '${vnetSpoke1.id}/subnets/AzureBastionSubnet'
          }
        }
      }
    ]
  }
}

@description('Public IP for Azure Bastion in On-Prem VNet')
resource bastionOnPremPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${deploymentPrefix}-bastion-onprem-pip'
  location: onPremLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Azure Bastion in On-Prem VNet for testing')
resource bastionOnPrem 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: '${deploymentPrefix}-bastion-onprem'
  location: onPremLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionOnPremPip.id
          }
          subnet: {
            id: '${vnetOnPrem.id}/subnets/AzureBastionSubnet'
          }
        }
      }
    ]
  }
}

// ============================================================================
// Test VMs
// ============================================================================

// Spoke 1 VM
@description('NIC for Spoke 1 VM')
resource vmSpoke1Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${deploymentPrefix}-vm-spoke1-nic'
  location: vwanLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnetSpoke1.id}/subnets/snet-workload'
          }
        }
      }
    ]
  }
}

@description('Test VM in Spoke 1')
resource vmSpoke1 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${deploymentPrefix}-vm-spoke1'
  location: vwanLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vmspoke1'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: 'latest'
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
          id: vmSpoke1Nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Spoke 2 VM
@description('NIC for Spoke 2 VM')
resource vmSpoke2Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${deploymentPrefix}-vm-spoke2-nic'
  location: vwanLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnetSpoke2.id}/subnets/snet-workload'
          }
        }
      }
    ]
  }
}

@description('Test VM in Spoke 2')
resource vmSpoke2 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${deploymentPrefix}-vm-spoke2'
  location: vwanLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vmspoke2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: 'latest'
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
          id: vmSpoke2Nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// On-Prem VM
@description('NIC for On-Prem VM')
resource vmOnPremNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${deploymentPrefix}-vm-onprem-nic'
  location: onPremLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnetOnPrem.id}/subnets/snet-workload'
          }
        }
      }
    ]
  }
}

@description('Test VM in On-Prem VNet')
resource vmOnPrem 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${deploymentPrefix}-vm-onprem'
  location: onPremLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vmonprem'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: 'latest'
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
          id: vmOnPremNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

// Virtual WAN Outputs
output virtualWanId string = virtualWan.id
output virtualWanName string = virtualWan.name

// Virtual Hub Outputs
output virtualHubId string = virtualHub.id
output virtualHubName string = virtualHub.name
output virtualHubAddressPrefix string = hubAddressPrefix

// Hub VPN Gateway Outputs
output hubVpnGatewayId string = hubVpnGateway.id
output hubVpnGatewayName string = hubVpnGateway.name

// Azure Firewall Outputs
output azureFirewallId string = azureFirewall.id
output azureFirewallName string = azureFirewall.name
output azureFirewallPrivateIp string = azureFirewall.properties.hubIPAddresses.privateIPAddress

// Spoke VNet Outputs
output vnetSpoke1Id string = vnetSpoke1.id
output vnetSpoke1Name string = vnetSpoke1.name
output vnetSpoke2Id string = vnetSpoke2.id
output vnetSpoke2Name string = vnetSpoke2.name

// On-Prem Outputs
output vnetOnPremId string = vnetOnPrem.id
output vnetOnPremName string = vnetOnPrem.name
output onPremVpnGatewayId string = onPremVpnGateway.id
output onPremVpnGatewayName string = onPremVpnGateway.name
output onPremVpnGatewayPublicIp string = onPremVpnGatewayPip.properties.ipAddress

// VPN Site and Connection Outputs
output vpnSiteId string = vpnSite.id
output vpnSiteName string = vpnSite.name
output vpnConnectionId string = vpnConnection.id
output vpnConnectionName string = vpnConnection.name

// Test VM Outputs
output vmSpoke1PrivateIp string = vmSpoke1Nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmSpoke2PrivateIp string = vmSpoke2Nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmOnPremPrivateIp string = vmOnPremNic.properties.ipConfigurations[0].properties.privateIPAddress

// Bastion Outputs
output bastionSpoke1Name string = bastionSpoke1.name
output bastionOnPremName string = bastionOnPrem.name
