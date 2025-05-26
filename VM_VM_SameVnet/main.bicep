@description('The username for the virtual machine administrator.')
param adminUsername string

@description('The password for the virtual machine administrator.')
@secure()
param adminPassword string 

@description('The allowed IP address for RDP access.')
param allowedRdpSourceAddress string

@description('The location of the resource group.')
param location string = resourceGroup().location

@description('Specifies whether to use Overlake VM size or not.')
@allowed([
  'Overlake'
  'Non-Overlake'
])
param vmSizeOption string

@description('Specifies whether to use a custom image or a default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

@description('The resource ID of the custom image to use if useCustomImage is true.')
//param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'
param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'

@description('The type of OS for the virtual machine.')
@allowed([
  'Windows'
  'Linux'
])
param osType string

@description('The image publisher for the VM.')
param imagePublisher string = osType == 'Windows' ? 'MicrosoftWindowsServer' : 'Canonical'

@description('The image offer for the VM.')
param imageOffer string = osType == 'Windows' ? 'WindowsServer' : '0001-com-ubuntu-server-focal'

@description('The image SKU for the VM.')
param imageSku string = osType == 'Windows' ? '2019-Datacenter' : '20_04-lts-gen2'

@description('The image version for the VM.')
param imageVersion string = 'latest'

var useCustomImageBool = useCustomImage == 'Yes' ? true : false 
var vmSize = vmSizeOption == 'Overlake' ? 'Standard_D2s_v5' : 'Standard_D2s_v4'

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
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
        }
      }
    ]
  }
}
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: 'myNsg'
  location: location
  properties: {
    securityRules: [
      osType == 'Windows' ? {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedRdpSourceAddress
          destinationAddressPrefix: '*'
        }
      } : {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedRdpSourceAddress
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'myPublicIp'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
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
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: 'myVm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: osType == 'Windows' ? {
      computerName: 'myVm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    } : {
      computerName: 'myVm'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: useCustomImageBool ? {
        id: customImageResourceId
      } : {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
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

resource publicIp2 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'myPublicIp2'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: 'myNic2'
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
            id: publicIp2.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: 'myVm2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: osType == 'Windows' ? {
      computerName: 'myVm2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    } : {
      computerName: 'myVm2'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: useCustomImageBool ? {
        id: customImageResourceId
      } : {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
        }
      ]
    }
  }
}




