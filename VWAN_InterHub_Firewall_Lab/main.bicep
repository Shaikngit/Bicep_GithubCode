// =============================================================================
// Azure Virtual WAN Inter-Hub Traffic Inspection Lab with Routing Intent
// =============================================================================
// This lab demonstrates hub-to-hub traffic inspection using Azure Firewall
// with Virtual WAN Routing Intent policies for private traffic routing.

targetScope = 'subscription'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Primary resource group name for the lab')
param resourceGroupName string = 'rg-vwan-interhub-lab'

@description('Primary deployment location (Southeast Asia)')
param primaryLocation string = 'southeastasia' 

// Secondary location is defined per hub in hubConfigs

@description('Virtual WAN configuration')
param vwanConfig object = {
  name: 'vwan-interhub-lab'
  allowBranchToBranchTraffic: true
  allowVnetToVnetTraffic: true
  type: 'Standard'
}

@description('Virtual Hub configurations')
param hubConfigs object = {
  hub1: {
    name: 'vhub-sea'
    location: 'southeastasia'
    addressPrefix: '10.1.0.0/16'
    hubRouting: {
      preferredRoutingGateway: 'ExpressRoute'
    }
  }
  hub2: {
    name: 'vhub-ea'
    location: 'eastasia' 
    addressPrefix: '10.2.0.0/16'
    hubRouting: {
      preferredRoutingGateway: 'ExpressRoute'
    }
  }
}

@description('Azure Firewall configuration')
param firewallConfig object = {
  sku: {
    name: 'AZFW_Hub'
    tier: 'Standard'
  }
  threatIntelMode: 'Alert'
  dnsSettings: {
    enableProxy: true
  }
}

@description('Spoke VNet configurations')
param spokeConfigs object = {
  spoke1: {
    name: 'vnet-spoke-sea'
    location: 'southeastasia'
    addressPrefix: '10.10.0.0/16'
    subnets: {
      vm: {
        name: 'subnet-vm'
        addressPrefix: '10.10.1.0/24'
      }
    }
  }
  spoke2: {
    name: 'vnet-spoke-ea'
    location: 'eastasia'
    addressPrefix: '10.20.0.0/16'
    subnets: {
      vm: {
        name: 'subnet-vm'
        addressPrefix: '10.20.1.0/24'
      }
    }
  }
}

@description('Virtual Machine configuration')
param vmConfig object = {
  adminUsername: 'azureuser'
  vmSize: 'Standard_B2s'
  imageReference: {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
  osDisk: {
    createOption: 'FromImage'
    storageAccountType: 'Premium_LRS'
    diskSizeGB: 30
  }
}

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Azure Bastion configuration')
param bastionConfig object = {
  name: 'bastion-interhub-lab'
  location: 'southeastasia'
  vnetPrefix: '10.100.0.0/16'
  subnetPrefix: '10.100.0.0/26'
}

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'Lab'
  Purpose: 'VWAN-InterHub-Firewall-Inspection'
  CreatedBy: 'Bicep'
  Project: 'Networking-Lab'
}

// =============================================================================
// VARIABLES
// =============================================================================

var deploymentPrefix = uniqueString(subscription().id, resourceGroupName)

// =============================================================================
// RESOURCE GROUP
// =============================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: primaryLocation
  tags: tags
}

// =============================================================================
// VIRTUAL WAN MODULE
// =============================================================================

module virtualWan 'modules/vwan.bicep' = {
  name: 'deploy-vwan-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    vwanConfig: vwanConfig
    location: primaryLocation
    tags: tags
  }
}

// =============================================================================
// VIRTUAL HUB MODULES
// =============================================================================

module virtualHub1 'modules/hub.bicep' = {
  name: 'deploy-hub1-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    hubConfig: hubConfigs.hub1
    virtualWanId: virtualWan.outputs.virtualWanId
    tags: tags
  }
}

module virtualHub2 'modules/hub.bicep' = {
  name: 'deploy-hub2-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    hubConfig: hubConfigs.hub2
    virtualWanId: virtualWan.outputs.virtualWanId
    tags: tags
  }
}

// =============================================================================
// AZURE FIREWALL MODULES
// =============================================================================

module azureFirewall1 'modules/firewall.bicep' = {
  name: 'deploy-firewall1-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    firewallName: 'azfw-${hubConfigs.hub1.name}'
    hubId: virtualHub1.outputs.hubId
    hubConfig: hubConfigs.hub1
    firewallConfig: firewallConfig
    tags: tags
  }
  // Implicit dependency through hubId parameter
}

module azureFirewall2 'modules/firewall.bicep' = {
  name: 'deploy-firewall2-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    firewallName: 'azfw-${hubConfigs.hub2.name}'
    hubId: virtualHub2.outputs.hubId
    hubConfig: hubConfigs.hub2
    firewallConfig: firewallConfig
    tags: tags
  }
  // Implicit dependency through hubId parameter
}

// =============================================================================
// ROUTING INTENT POLICIES
// =============================================================================

module routingIntent1 'modules/routing-intent.bicep' = {
  name: 'deploy-routing-intent1-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    hubId: virtualHub1.outputs.hubId
    firewallId: azureFirewall1.outputs.firewallId
  }
  // Implicit dependency through firewallId parameter
}

module routingIntent2 'modules/routing-intent.bicep' = {
  name: 'deploy-routing-intent2-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    hubId: virtualHub2.outputs.hubId
    firewallId: azureFirewall2.outputs.firewallId
  }
  // Implicit dependency through firewallId parameter
}

// =============================================================================
// SPOKE VNETS AND VMS
// =============================================================================

module spoke1 'modules/spoke.bicep' = {
  name: 'deploy-spoke1-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    spokeConfig: spokeConfigs.spoke1
    vmConfig: vmConfig
    adminPassword: adminPassword
    hubId: virtualHub1.outputs.hubId
    tags: tags
  }
  dependsOn: [
    routingIntent1
  ]
}

module spoke2 'modules/spoke.bicep' = {
  name: 'deploy-spoke2-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    spokeConfig: spokeConfigs.spoke2
    vmConfig: vmConfig
    adminPassword: adminPassword
    hubId: virtualHub2.outputs.hubId
    tags: tags
  }
  dependsOn: [
    routingIntent2
  ]
}

// =============================================================================
// AZURE BASTION FOR SECURE VM ACCESS
// =============================================================================

module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion-${deploymentPrefix}'
  scope: resourceGroup
  params: {
    bastionConfig: bastionConfig
    hubId: virtualHub1.outputs.hubId
    tags: tags
  }
  dependsOn: [
    spoke1
    spoke2
  ]
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Virtual WAN resource ID')
output virtualWanId string = virtualWan.outputs.virtualWanId

@description('Virtual WAN name')
output virtualWanName string = virtualWan.outputs.virtualWanName

@description('Hub 1 details')
output hub1Details object = {
  id: virtualHub1.outputs.hubId
  name: virtualHub1.outputs.hubName
  location: hubConfigs.hub1.location
  addressPrefix: hubConfigs.hub1.addressPrefix
  firewallPrivateIP: azureFirewall1.outputs.firewallPrivateIP
}

@description('Hub 2 details')
output hub2Details object = {
  id: virtualHub2.outputs.hubId
  name: virtualHub2.outputs.hubName
  location: hubConfigs.hub2.location
  addressPrefix: hubConfigs.hub2.addressPrefix
  firewallPrivateIP: azureFirewall2.outputs.firewallPrivateIP
}

@description('VM details for testing')
output vmDetails object = {
  vm1: {
    name: spoke1.outputs.vmName
    publicIP: spoke1.outputs.vmPublicIP
    privateIP: spoke1.outputs.vmPrivateIP
    location: spokeConfigs.spoke1.location
    sshCommand: 'ssh ${vmConfig.adminUsername}@${spoke1.outputs.vmPublicIP}'
  }
  vm2: {
    name: spoke2.outputs.vmName
    publicIP: spoke2.outputs.vmPublicIP
    privateIP: spoke2.outputs.vmPrivateIP
    location: spokeConfigs.spoke2.location
    sshCommand: 'ssh ${vmConfig.adminUsername}@${spoke2.outputs.vmPublicIP}'
  }
}

@description('Firewall details')
output firewallDetails object = {
  firewall1: {
    id: azureFirewall1.outputs.firewallId
    name: azureFirewall1.outputs.firewallName
    privateIP: azureFirewall1.outputs.firewallPrivateIP
    location: hubConfigs.hub1.location
  }
  firewall2: {
    id: azureFirewall2.outputs.firewallId
    name: azureFirewall2.outputs.firewallName
    privateIP: azureFirewall2.outputs.firewallPrivateIP
    location: hubConfigs.hub2.location
  }
}

@description('Test connectivity commands')
output testCommands object = {
  pingVM1toVM2: 'ping ${spoke2.outputs.vmPrivateIP}'
  pingVM2toVM1: 'ping ${spoke1.outputs.vmPrivateIP}'
  curlVM1toVM2: 'curl -v telnet://${spoke2.outputs.vmPrivateIP}:22'
  curlVM2toVM1: 'curl -v telnet://${spoke1.outputs.vmPrivateIP}:22'
}

@description('Azure Bastion details')
output bastionDetails object = {
  name: bastion.outputs.bastionName
  publicIP: bastion.outputs.bastionPublicIP
  vnetName: bastion.outputs.bastionVnetName
  location: bastionConfig.location
  connectCommand: 'az network bastion ssh --name ${bastion.outputs.bastionName} --resource-group ${resourceGroupName} --target-resource-id <vm-resource-id> --auth-type password --username ${vmConfig.adminUsername}'
}

@description('Resource group name')
output resourceGroupName string = resourceGroup.name
