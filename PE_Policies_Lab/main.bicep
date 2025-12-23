// ============================================================================
// PE Policies Lab - Private Endpoint Network Policies with Optional Azure Firewall
// ============================================================================
// This lab demonstrates Private Endpoint Network Policies behavior
// 
// Architecture WITHOUT Firewall:
//   Client VM → Private Endpoint → Private Link Service → Internal LB → IIS Web Server
//
// Architecture WITH Firewall:
//   Client VM → Route Table → Azure Firewall → Private Endpoint → Private Link Service → Internal LB → IIS Web Server
//
// Key Concepts:
//   - privateEndpointNetworkPolicies: 'Enabled' allows NSG and UDR to apply to PE traffic
//   - Private Link Service provides private connectivity to Internal Load Balancer
//   - When firewall is deployed, UDR forces PE traffic through Azure Firewall
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Deployment prefix for resource naming')
param deploymentPrefix string = 'pelab'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Deploy Azure Firewall for traffic inspection')
param deployAzureFirewall bool = false

@description('VM Size - Use non-Overlake SKU for cost efficiency')
param vmSize string = 'Standard_D2s_v4'

// ============================================================================
// Variables
// ============================================================================

var clientVnetName = '${deploymentPrefix}-client-vnet'
var serviceVnetName = '${deploymentPrefix}-service-vnet'
var clientVmName = '${deploymentPrefix}-client-vm'
var webVmName = '${deploymentPrefix}-web-vm'
var bastionName = '${deploymentPrefix}-bastion'
var bastionPipName = '${deploymentPrefix}-bastion-pip'
var ilbName = '${deploymentPrefix}-ilb'
var plsName = '${deploymentPrefix}-pls'
var peName = '${deploymentPrefix}-pe'
var firewallName = '${deploymentPrefix}-fw'
var firewallPipName = '${deploymentPrefix}-fw-pip'
var routeTableName = '${deploymentPrefix}-rt-pe-subnet'
var peNsgName = '${deploymentPrefix}-pe-nsg'

// Client VNet address space
var clientVnetAddressPrefix = '10.10.0.0/16'
var clientVmSubnetPrefix = '10.10.0.0/24'
var clientPeSubnetPrefix = '10.10.1.0/24'
var bastionSubnetPrefix = '10.10.2.0/24'
var firewallSubnetPrefix = '10.10.3.0/24'

// Service VNet address space
var serviceVnetAddressPrefix = '10.20.0.0/16'
var webSubnetPrefix = '10.20.0.0/24'
var plsSubnetPrefix = '10.20.1.0/24'

// ============================================================================
// Network Security Group for PE Subnet - Demonstrates PE Policies
// ============================================================================

resource peNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: peNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: clientVmSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: clientPeSubnetPrefix
          destinationPortRange: '80'
          description: 'Allow HTTP from Client VM subnet to PE subnet'
        }
      }
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: clientVmSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: clientPeSubnetPrefix
          destinationPortRange: '443'
          description: 'Allow HTTPS from Client VM subnet to PE subnet'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic - Tests PE Network Policies'
        }
      }
    ]
  }
}

// ============================================================================
// Client Virtual Network (Without Firewall)
// ============================================================================

resource clientVnetNoFw 'Microsoft.Network/virtualNetworks@2023-11-01' = if (!deployAzureFirewall) {
  name: clientVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [clientVnetAddressPrefix]
    }
    subnets: [
      {
        name: 'vm-subnet'
        properties: {
          addressPrefix: clientVmSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'pe-subnet'
        properties: {
          addressPrefix: clientPeSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: peNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// ============================================================================
// Client Virtual Network (With Firewall) - Deployed first without route table
// ============================================================================

resource clientVnetWithFw 'Microsoft.Network/virtualNetworks@2023-11-01' = if (deployAzureFirewall) {
  name: clientVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [clientVnetAddressPrefix]
    }
    subnets: [
      {
        name: 'vm-subnet'
        properties: {
          addressPrefix: clientVmSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'pe-subnet'
        properties: {
          addressPrefix: clientPeSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: peNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
    ]
  }
}

// ============================================================================
// Azure Firewall (Optional)
// ============================================================================

resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployAzureFirewall) {
  name: firewallPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = if (deployAzureFirewall) {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          publicIPAddress: {
            id: firewallPip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', clientVnetName, 'AzureFirewallSubnet')
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'AllowPETraffic'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowHTTPtoPE'
              protocols: ['TCP']
              sourceAddresses: [clientVmSubnetPrefix]
              destinationAddresses: [serviceVnetAddressPrefix]
              destinationPorts: ['80', '443']
            }
          ]
        }
      }
    ]
  }
  dependsOn: [clientVnetWithFw]
}

// ============================================================================
// Route Table for PE Subnet (Only when Firewall is deployed)
// Created after firewall to get its IP, then attached to subnet
// ============================================================================

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = if (deployAzureFirewall) {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'route-to-service-vnet-via-firewall'
        properties: {
          addressPrefix: serviceVnetAddressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall!.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

// Update PE subnet with route table after firewall is created
resource peSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = if (deployAzureFirewall) {
  name: '${clientVnetName}/pe-subnet'
  properties: {
    addressPrefix: clientPeSubnetPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: peNsg.id
    }
    routeTable: {
      id: routeTable.id
    }
  }
  dependsOn: [clientVnetWithFw]
}

// ============================================================================
// Service Virtual Network
// ============================================================================

resource serviceVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: serviceVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [serviceVnetAddressPrefix]
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: {
          addressPrefix: webSubnetPrefix
        }
      }
      {
        name: 'pls-subnet'
        properties: {
          addressPrefix: plsSubnetPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ============================================================================
// VNet Peering (Only when Firewall is deployed - for firewall to route traffic)
// ============================================================================

resource clientToServicePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = if (deployAzureFirewall) {
  name: '${clientVnetName}/client-to-service'
  properties: {
    remoteVirtualNetwork: {
      id: serviceVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [clientVnetWithFw]
}

resource serviceToClientPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = if (deployAzureFirewall) {
  name: '${serviceVnetName}/service-to-client'
  properties: {
    remoteVirtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', clientVnetName)
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [clientVnetWithFw, serviceVnet]
}

// ============================================================================
// Bastion for Secure VM Access
// ============================================================================

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionPip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', clientVnetName, 'AzureBastionSubnet')
          }
        }
      }
    ]
  }
  dependsOn: deployAzureFirewall ? [clientVnetWithFw] : [clientVnetNoFw]
}

// ============================================================================
// Client VM - Test machine to connect to services via PE
// ============================================================================

resource clientVmNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${clientVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', clientVnetName, 'vm-subnet')
          }
        }
      }
    ]
  }
  dependsOn: deployAzureFirewall ? [clientVnetWithFw] : [clientVnetNoFw]
}

resource clientVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: clientVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'clientvm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: clientVmNic.id
        }
      ]
    }
  }
}

// ============================================================================
// Web Server VM - IIS behind Internal Load Balancer
// ============================================================================

resource webVmNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${webVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', serviceVnetName, 'web-subnet')
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', ilbName, 'backend-pool')
            }
          ]
        }
      }
    ]
  }
  dependsOn: [serviceVnet, ilb]
}

resource webVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: webVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'webserver'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: webVmNic.id
        }
      ]
    }
  }
}

// Install IIS on Web Server
resource webVmIIS 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: webVm
  name: 'InstallIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value \'<html><head><title>PE Policies Lab</title></head><body><h1>Success!</h1><p>You have reached the IIS Web Server via Private Endpoint and Private Link Service.</p><p>Server: webserver</p><p>PE Policies are working correctly.</p></body></html>\'"'
    }
  }
}

// ============================================================================
// Internal Load Balancer
// ============================================================================

resource ilb 'Microsoft.Network/loadBalancers@2023-11-01' = {
  name: ilbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', serviceVnetName, 'web-subnet')
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', ilbName, 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', ilbName, 'backend-pool')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', ilbName, 'http-probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
  dependsOn: [serviceVnet]
}

// ============================================================================
// Private Link Service
// ============================================================================

resource pls 'Microsoft.Network/privateLinkServices@2023-11-01' = {
  name: plsName
  location: location
  properties: {
    loadBalancerFrontendIpConfigurations: [
      {
        id: ilb.properties.frontendIPConfigurations[0].id
      }
    ]
    ipConfigurations: [
      {
        name: 'pls-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', serviceVnetName, 'pls-subnet')
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    visibility: {
      subscriptions: []
    }
    autoApproval: {
      subscriptions: []
    }
    enableProxyProtocol: false
  }
  dependsOn: [serviceVnet]
}

// ============================================================================
// Private Endpoint
// ============================================================================

resource pe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', clientVnetName, 'pe-subnet')
    }
    privateLinkServiceConnections: [
      {
        name: '${peName}-connection'
        properties: {
          privateLinkServiceId: pls.id
          requestMessage: 'Please approve this connection'
        }
      }
    ]
  }
  dependsOn: deployAzureFirewall ? [clientVnetWithFw, pls, peSubnetUpdate] : [clientVnetNoFw, pls]
}

// ============================================================================
// Outputs
// ============================================================================

output serviceVnetId string = serviceVnet.id
output clientVmName string = clientVm.name
output webVmName string = webVm.name
output ilbName string = ilb.name
output plsName string = pls.name
output peName string = pe.name
output bastionName string = bastion.name
output firewallDeployed bool = deployAzureFirewall
output peSubnetHasNsg bool = true
output peNetworkPoliciesEnabled bool = true

