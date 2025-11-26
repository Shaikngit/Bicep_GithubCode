// ============================================================================
// VWAN Route Table Isolation Lab
// ============================================================================
// This template deploys a Virtual WAN lab for testing route table isolation.
// - Virtual WAN Hub in SoutheastAsia
// - 3 VNets (A, B, C) in SoutheastAsia connected to hub
// - 2 Branch VNets in EastAsia with VPN Gateways
// - Custom route tables to isolate VNet_A from Branch traffic
// ============================================================================

@description('Admin username for all VMs')
param adminUsername string

@description('Admin password for all VMs')
@secure()
param adminPassword string

@description('Location for Virtual WAN and Hub')
param hubLocation string = 'southeastasia'

@description('Location for Branch VNets and VPN Gateways')
param branchLocation string = 'eastasia'

@description('VM Size for all VMs')
param vmSize string = 'Standard_B2s'

// ============================================================================
// Variables
// ============================================================================
var vwanName = 'vwan-test'
var vhubName = 'vhub-test'
var vhubAddressPrefix = '10.0.0.0/24'

// VNet configurations
var vnets = [
  {
    name: 'VNet_A'
    addressPrefix: '10.1.0.0/16'
    subnetPrefix: '10.1.0.0/24'
    subnetName: 'subnet-a'
    vmName: 'vm-a'
    location: hubLocation
  }
  {
    name: 'VNet_B'
    addressPrefix: '10.2.0.0/16'
    subnetPrefix: '10.2.0.0/24'
    subnetName: 'subnet-b'
    vmName: 'vm-b'
    location: hubLocation
  }
  {
    name: 'VNet_C'
    addressPrefix: '10.3.0.0/16'
    subnetPrefix: '10.3.0.0/24'
    subnetName: 'subnet-c'
    vmName: 'vm-c'
    location: hubLocation
  }
]

// Branch configurations
var branches = [
  {
    name: 'Branch_A'
    addressPrefix: '10.10.0.0/16'
    subnetPrefix: '10.10.0.0/24'
    gatewaySubnetPrefix: '10.10.255.0/27'
    subnetName: 'subnet-branchA'
    vmName: 'vm-branchA'
    location: branchLocation
    asn: 65010
    bgpPeerAddress: '169.254.10.1'
  }
  {
    name: 'Branch_B'
    addressPrefix: '10.20.0.0/16'
    subnetPrefix: '10.20.0.0/24'
    gatewaySubnetPrefix: '10.20.255.0/27'
    subnetName: 'subnet-branchB'
    vmName: 'vm-branchB'
    location: branchLocation
    asn: 65020
    bgpPeerAddress: '169.254.20.1'
  }
]

// All lab address ranges for NSG rules
var labAddressRanges = [
  '10.0.0.0/24'   // Hub
  '10.1.0.0/16'   // VNet_A
  '10.2.0.0/16'   // VNet_B
  '10.3.0.0/16'   // VNet_C
  '10.10.0.0/16'  // Branch_A
  '10.20.0.0/16'  // Branch_B
  '10.100.0.0/16' // Bastion VNet
]

// Bastion configuration
var bastionVnetName = 'VNet_Bastion'
var bastionVnetAddressPrefix = '10.100.0.0/16'
var bastionSubnetPrefix = '10.100.0.0/26'  // AzureBastionSubnet requires /26 or larger
var bastionName = 'bastion-vwan-lab'

// ============================================================================
// Virtual WAN
// ============================================================================
resource virtualWan 'Microsoft.Network/virtualWans@2024-01-01' = {
  name: vwanName
  location: hubLocation
  properties: {
    type: 'Standard'
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
  }
}

// ============================================================================
// Virtual Hub
// ============================================================================
resource virtualHub 'Microsoft.Network/virtualHubs@2024-01-01' = {
  name: vhubName
  location: hubLocation
  properties: {
    virtualWan: {
      id: virtualWan.id
    }
    addressPrefix: vhubAddressPrefix
    sku: 'Standard'
  }
}

// ============================================================================
// Custom Route Tables
// ============================================================================

// RouteTable_A - For VNet_A isolation (no branch routes)
resource routeTableA 'Microsoft.Network/virtualHubs/hubRouteTables@2024-01-01' = {
  parent: virtualHub
  name: 'RouteTable_A'
  properties: {
    labels: [
      'RouteTable_A'
    ]
    routes: []
  }
  dependsOn: [
    vpnGateway
  ]
}

// RouteTable_B - For Branch isolation (no VNet_A routes)
resource routeTableB 'Microsoft.Network/virtualHubs/hubRouteTables@2024-01-01' = {
  parent: virtualHub
  name: 'RouteTable_B'
  properties: {
    labels: [
      'RouteTable_B'
    ]
    routes: []
  }
  dependsOn: [
    vpnGateway
  ]
}

// ============================================================================
// VPN Gateway in Virtual Hub
// ============================================================================
resource vpnGateway 'Microsoft.Network/vpnGateways@2024-01-01' = {
  name: '${vhubName}-vpngw'
  location: hubLocation
  properties: {
    virtualHub: {
      id: virtualHub.id
    }
    vpnGatewayScaleUnit: 1
    bgpSettings: {
      asn: 65515
    }
  }
}

// ============================================================================
// NSGs for VNets
// ============================================================================
resource nsgVnets 'Microsoft.Network/networkSecurityGroups@2024-01-01' = [for (vnet, i) in vnets: {
  name: 'nsg-${vnet.name}'
  location: vnet.location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-AzurePlatform'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '168.63.129.16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Azure platform for Bastion native client'
        }
      }
      {
        name: 'Allow-SSH-From-Lab'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: labAddressRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-ICMP-From-Lab'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefixes: labAddressRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-SSH-From-Internet'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}]

// ============================================================================
// VNets in SoutheastAsia
// ============================================================================
resource vnetResources 'Microsoft.Network/virtualNetworks@2024-01-01' = [for (vnet, i) in vnets: {
  name: vnet.name
  location: vnet.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet.addressPrefix
      ]
    }
    subnets: [
      {
        name: vnet.subnetName
        properties: {
          addressPrefix: vnet.subnetPrefix
          networkSecurityGroup: {
            id: nsgVnets[i].id
          }
        }
      }
    ]
  }
}]

// ============================================================================
// NICs for VNet VMs
// ============================================================================
resource nicVnets 'Microsoft.Network/networkInterfaces@2024-01-01' = [for (vnet, i) in vnets: {
  name: 'nic-${vnet.vmName}'
  location: vnet.location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetResources[i].properties.subnets[0].id
          }
        }
      }
    ]
  }
}]

// ============================================================================
// VMs in VNets
// ============================================================================
resource vmVnets 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (vnet, i) in vnets: {
  name: vnet.vmName
  location: vnet.location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vnet.vmName
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
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVnets[i].id
        }
      ]
    }
  }
}]

// ============================================================================
// VNet Connections to Hub
// ============================================================================

// VNet_A connection - Associated with RouteTable_A, propagates only to RouteTable_A
resource vnetConnectionA 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  parent: virtualHub
  name: 'conn-VNet_A'
  properties: {
    remoteVirtualNetwork: {
      id: vnetResources[0].id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: false
    routingConfiguration: {
      associatedRouteTable: {
        id: routeTableA.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: routeTableA.id
          }
        ]
        labels: [
          'RouteTable_A'
        ]
      }
    }
  }
}

// VNet_B connection - Uses default route table with full propagation
resource vnetConnectionB 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  parent: virtualHub
  name: 'conn-VNet_B'
  properties: {
    remoteVirtualNetwork: {
      id: vnetResources[1].id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: false
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
          }
          {
            id: routeTableB.id
          }
        ]
        labels: [
          'default'
          'RouteTable_B'
        ]
      }
    }
  }
  dependsOn: [
    vnetConnectionA
  ]
}

// VNet_C connection - Uses default route table with full propagation
resource vnetConnectionC 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  parent: virtualHub
  name: 'conn-VNet_C'
  properties: {
    remoteVirtualNetwork: {
      id: vnetResources[2].id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: false
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
          }
          {
            id: routeTableB.id
          }
        ]
        labels: [
          'default'
          'RouteTable_B'
        ]
      }
    }
  }
  dependsOn: [
    vnetConnectionB
  ]
}

// ============================================================================
// Azure Bastion for Secure VM Access
// ============================================================================

// Bastion VNet with AzureBastionSubnet
resource bastionVnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: bastionVnetName
  location: hubLocation
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
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// Public IP for Bastion
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${bastionName}-pip'
  location: hubLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Bastion
resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionName
  location: hubLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true  // Allows native client (SSH/RDP from your laptop)
    enableIpConnect: true  // Allows connection via IP address
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastionVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// Connect Bastion VNet to VWAN Hub for routing to all VMs
resource vnetConnectionBastion 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  parent: virtualHub
  name: 'conn-VNet_Bastion'
  properties: {
    remoteVirtualNetwork: {
      id: bastionVnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: false
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
          }
          {
            id: routeTableA.id
          }
          {
            id: routeTableB.id
          }
        ]
        labels: [
          'default'
          'RouteTable_A'
          'RouteTable_B'
        ]
      }
    }
  }
  dependsOn: [
    vnetConnectionC
    bastion
  ]
}

// ============================================================================
// Branch NSGs
// ============================================================================
resource nsgBranches 'Microsoft.Network/networkSecurityGroups@2024-01-01' = [for (branch, i) in branches: {
  name: 'nsg-${branch.name}'
  location: branch.location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-AzurePlatform'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '168.63.129.16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Azure platform for Bastion native client'
        }
      }
      {
        name: 'Allow-SSH-From-Lab'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: labAddressRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-ICMP-From-Lab'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefixes: labAddressRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-SSH-From-Internet'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}]

// ============================================================================
// Branch VNets in EastAsia
// ============================================================================
resource branchVnets 'Microsoft.Network/virtualNetworks@2024-01-01' = [for (branch, i) in branches: {
  name: branch.name
  location: branch.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        branch.addressPrefix
      ]
    }
    subnets: [
      {
        name: branch.subnetName
        properties: {
          addressPrefix: branch.subnetPrefix
          networkSecurityGroup: {
            id: nsgBranches[i].id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: branch.gatewaySubnetPrefix
        }
      }
    ]
  }
}]

// ============================================================================
// Branch Public IPs for VPN Gateways
// ============================================================================
resource branchPips 'Microsoft.Network/publicIPAddresses@2024-01-01' = [for (branch, i) in branches: {
  name: 'pip-vpngw-${branch.name}'
  location: branch.location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

// ============================================================================
// Branch VPN Gateways
// ============================================================================
resource branchVpnGateways 'Microsoft.Network/virtualNetworkGateways@2024-01-01' = [for (branch, i) in branches: {
  name: 'vpngw-${branch.name}'
  location: branch.location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    enableBgp: true
    activeActive: false
    bgpSettings: {
      asn: branch.asn
      bgpPeeringAddress: ''
      peerWeight: 0
      bgpPeeringAddresses: [
        {
          ipconfigurationId: resourceId('Microsoft.Network/virtualNetworkGateways/ipConfigurations', 'vpngw-${branch.name}', 'vnetGatewayConfig')
          customBgpIpAddresses: [
            branch.bgpPeerAddress
          ]
        }
      ]
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${branchVnets[i].id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: branchPips[i].id
          }
        }
      }
    ]
  }
}]

// ============================================================================
// Branch NICs
// ============================================================================
resource nicBranches 'Microsoft.Network/networkInterfaces@2024-01-01' = [for (branch, i) in branches: {
  name: 'nic-${branch.vmName}'
  location: branch.location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: branchVnets[i].properties.subnets[0].id
          }
        }
      }
    ]
  }
}]

// ============================================================================
// Branch VMs
// ============================================================================
resource vmBranches 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (branch, i) in branches: {
  name: branch.vmName
  location: branch.location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: branch.vmName
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
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicBranches[i].id
        }
      ]
    }
  }
}]

// ============================================================================
// VPN Sites (Representing Branch Gateways)
// ============================================================================
resource vpnSites 'Microsoft.Network/vpnSites@2024-01-01' = [for (branch, i) in branches: {
  name: 'site-${branch.name}'
  location: hubLocation
  properties: {
    virtualWan: {
      id: virtualWan.id
    }
    deviceProperties: {
      deviceVendor: 'Microsoft'
      linkSpeedInMbps: 100
    }
    addressSpace: {
      addressPrefixes: [
        branch.addressPrefix
      ]
    }
    vpnSiteLinks: [
      {
        name: 'link-${branch.name}'
        properties: {
          ipAddress: branchPips[i].properties.ipAddress
          linkProperties: {
            linkProviderName: 'Azure'
            linkSpeedInMbps: 100
          }
          bgpProperties: {
            asn: branch.asn
            bgpPeeringAddress: branch.bgpPeerAddress
          }
        }
      }
    ]
  }
  dependsOn: [
    branchVpnGateways[i]
  ]
}]

// ============================================================================
// VPN Connections from Hub to Branch Sites
// ============================================================================
resource vpnConnectionBranchA 'Microsoft.Network/vpnGateways/vpnConnections@2024-01-01' = {
  parent: vpnGateway
  name: 'conn-Branch_A'
  properties: {
    remoteVpnSite: {
      id: vpnSites[0].id
    }
    vpnLinkConnections: [
      {
        name: 'link-Branch_A'
        properties: {
          vpnSiteLink: {
            id: '${vpnSites[0].id}/vpnSiteLinks/link-Branch_A'
          }
          enableBgp: true
          connectionBandwidth: 100
          vpnConnectionProtocolType: 'IKEv2'
          sharedKey: 'VwanBranchASharedKey123!'
        }
      }
    ]
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: routeTableB.id
          }
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
          }
        ]
        labels: [
          'RouteTable_B'
          'default'
        ]
      }
    }
  }
  dependsOn: [
    vnetConnectionC
  ]
}

resource vpnConnectionBranchB 'Microsoft.Network/vpnGateways/vpnConnections@2024-01-01' = {
  parent: vpnGateway
  name: 'conn-Branch_B'
  properties: {
    remoteVpnSite: {
      id: vpnSites[1].id
    }
    vpnLinkConnections: [
      {
        name: 'link-Branch_B'
        properties: {
          vpnSiteLink: {
            id: '${vpnSites[1].id}/vpnSiteLinks/link-Branch_B'
          }
          enableBgp: true
          connectionBandwidth: 100
          vpnConnectionProtocolType: 'IKEv2'
          sharedKey: 'VwanBranchBSharedKey456!'
        }
      }
    ]
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: routeTableB.id
          }
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vhubName, 'defaultRouteTable')
          }
        ]
        labels: [
          'RouteTable_B'
          'default'
        ]
      }
    }
  }
  dependsOn: [
    vpnConnectionBranchA
  ]
}

// ============================================================================
// Local Network Gateways (for Branch VPN Gateways to connect to VWAN)
// ============================================================================
resource localNetworkGateways 'Microsoft.Network/localNetworkGateways@2024-01-01' = [for (branch, i) in branches: {
  name: 'lng-${branch.name}-to-vwan'
  location: branch.location
  properties: {
    gatewayIpAddress: vpnGateway.properties.ipConfigurations[0].publicIpAddress
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: vpnGateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
    }
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.0.0.0/24'   // Hub
        '10.1.0.0/16'   // VNet_A (will be filtered by route tables)
        '10.2.0.0/16'   // VNet_B
        '10.3.0.0/16'   // VNet_C
      ]
    }
  }
  dependsOn: [
    vpnConnectionBranchB
  ]
}]

// ============================================================================
// Branch VPN Connections to VWAN Hub
// ============================================================================
resource branchToHubConnections 'Microsoft.Network/connections@2024-01-01' = [for (branch, i) in branches: {
  name: 'conn-${branch.name}-to-vwan'
  location: branch.location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: branchVpnGateways[i].id
      properties: {}
    }
    localNetworkGateway2: {
      id: localNetworkGateways[i].id
      properties: {}
    }
    enableBgp: true
    sharedKey: i == 0 ? 'VwanBranchASharedKey123!' : 'VwanBranchBSharedKey456!'
    connectionProtocol: 'IKEv2'
  }
}]

// ============================================================================
// Outputs
// ============================================================================
output virtualWanId string = virtualWan.id
output virtualWanName string = virtualWan.name
output virtualHubId string = virtualHub.id
output virtualHubName string = virtualHub.name

output routeTableNames object = {
  routeTableA: 'RouteTable_A'
  routeTableB: 'RouteTable_B'
  defaultRouteTable: 'defaultRouteTable'
}

output vpnGatewayPublicIps object = {
  branchAGatewayPip: branchPips[0].properties.ipAddress
  branchBGatewayPip: branchPips[1].properties.ipAddress
  hubVpnGatewayIp: vpnGateway.properties.ipConfigurations[0].publicIpAddress
}

output vnetConnectionNames array = [
  'conn-VNet_A'
  'conn-VNet_B'
  'conn-VNet_C'
]

output vmPrivateIps object = {
  vmA: nicVnets[0].properties.ipConfigurations[0].properties.privateIPAddress
  vmB: nicVnets[1].properties.ipConfigurations[0].properties.privateIPAddress
  vmC: nicVnets[2].properties.ipConfigurations[0].properties.privateIPAddress
  vmBranchA: nicBranches[0].properties.ipConfigurations[0].properties.privateIPAddress
  vmBranchB: nicBranches[1].properties.ipConfigurations[0].properties.privateIPAddress
}

output branchVpnConnectionNames array = [
  'conn-Branch_A'
  'conn-Branch_B'
]

output hubVpnGatewayName string = vpnGateway.name
output hubVpnGatewayId string = vpnGateway.id

// Bastion outputs
output bastionName string = bastion.name
output bastionId string = bastion.id
output bastionVnetName string = bastionVnet.name
output bastionPublicIp string = bastionPublicIp.properties.ipAddress
