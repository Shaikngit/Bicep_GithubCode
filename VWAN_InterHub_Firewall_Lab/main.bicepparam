using 'main.bicep'

// =============================================================================
// Virtual WAN Inter-Hub Traffic Inspection Lab Parameters
// =============================================================================
// NOTE: adminPassword must be provided at deployment time via CLI
//       Example: --parameters adminPassword='YourStrongPassword123!'

// Admin Password for VMs (secure parameter)
// Note: This parameter should be provided at deployment time
// Example: az deployment group create ... --parameters adminPassword='YourPassword'

// Resource Group Configuration
param resourceGroupName = 'rg-vwan-interhub-lab'
param primaryLocation = 'southeastasia'

// Virtual WAN Configuration
param vwanConfig = {
  name: 'vwan-interhub-lab'
  allowBranchToBranchTraffic: true
  allowVnetToVnetTraffic: true
  type: 'Standard'
}

// Virtual Hub Configurations
param hubConfigs = {
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

// Azure Firewall Configuration
param firewallConfig = {
  sku: {
    name: 'AZFW_Hub'
    tier: 'Standard'
  }
  threatIntelMode: 'Alert'
  dnsSettings: {
    enableProxy: true
  }
}

// Spoke VNet Configurations
param spokeConfigs = {
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

// Virtual Machine Configuration
param vmConfig = {
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

// Resource Tags
param tags = {
  Environment: 'Lab'
  Purpose: 'VWAN-InterHub-Firewall-Inspection'
  CreatedBy: 'Bicep'
  Project: 'Networking-Lab'
  Owner: 'YourName'
  CostCenter: 'IT-Training'
}
