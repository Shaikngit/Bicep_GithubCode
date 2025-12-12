@description('The username for the virtual machine administrator.')
param adminUsername string

@description('The password for the virtual machine administrator.')
@secure()
param adminPassword string 

@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string

@description('The location of the resource group.')
param location string = resourceGroup().location

@description('Specifies whether to use a custom image or a default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

@description('The resource ID of the custom image to use if useCustomImage is true.')
param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'

var useCustomImageBool = useCustomImage == 'Yes' ? true : false 
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'clientVNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'myNsg'
  location: location
  properties: {
    securityRules: []
  }
}

// Bastion Public IP - Standard SKU required for Bastion
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// VM Public IP - for internet access to install tools
resource vmPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'vm-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Bastion for secure VM access
resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: 'myBastion'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'myNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmPublicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'myVm'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'myVm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: useCustomImageBool ? {
        id: customImageResourceId
      } : {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output bastionName string = bastion.name
output vmName string = vm.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmPublicIp string = vmPublicIp.properties.ipAddress
output vmPrincipalId string = vm.identity.principalId
