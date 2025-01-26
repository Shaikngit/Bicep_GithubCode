// main.bicep

// Parameters
param location string = resourceGroup().location

@description('Admin Password for the VMs and SQL Server')
@secure()
param adminpassword string

param adminusername string
param allowedRdpSourceAddress string

@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string

@description('Specifies whether to use a custom image or a default image. Select "Yes" for custom image, "No" for default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

// Modules
module clientVM 'clientVM/client.bicep' = {
  name: 'clientVMDeployment'
  params: {
    location: location
    adminPassword: adminpassword
    adminUsername: adminusername
    allowedRdpSourceAddress: allowedRdpSourceAddress
    useCustomImage: useCustomImage
    vmSizeOption: vmSizeOption
  }
}

module firewall 'firewall/firewall.bicep' = {
  name: 'firewallDeployment'
  params: {
    location: location
 
  }
}

module sqlServer 'pesqlserver/sqlServer.bicep' = {
  name: 'sqlServerDeployment'
  params: {
    location: location
    sqlAdministratorLogin: adminusername
    sqlAdministratorLoginPassword: adminpassword
    vmAdminPassword: adminpassword
    vmAdminUsername: adminusername
  }
}

resource vnetPeeringClientToSql 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'ClientVNET/clientToSqlPeering'
    properties: {
    remoteVirtualNetwork: {
      id: sqlServer.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource vnetPeeringSqlToClient 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'sqlpeVNET/sqlToClientPeering'
  properties: {
    remoteVirtualNetwork: {
      id: clientVM.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource vnetPeeringClientToFirewall 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'clientVNET/clientToFirewallPeering'
  properties: {
    remoteVirtualNetwork: {
      id: firewall.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource vnetPeeringFirewallToClient 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'FirewallVNET/firewallToClientPeering'
  properties: {
    remoteVirtualNetwork: {
      id: clientVM.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource vnetPeeringSqlToFirewall 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'sqlpeVNET/sqlToFirewallPeering'
  properties: {
    remoteVirtualNetwork: {
      id: firewall.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource vnetPeeringFirewallToSql 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: 'FirewallVNET/firewallToSqlPeering'
  properties: {
    remoteVirtualNetwork: {
      id: sqlServer.outputs.vnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource routeTable 'Microsoft.Network/routeTables@2020-11-01' = {
  name: 'clientVMRouteTable'
  location: location
  properties: {
    routes: [
      {
        name: 'routeToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.outputs.firewallIpAddress
        }
      }
    ]
  }
}

