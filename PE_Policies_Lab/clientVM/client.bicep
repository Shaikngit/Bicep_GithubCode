@description('The username for the virtual machine administrator.')
param adminUsername string

@description('The password for the virtual machine administrator.')
@secure()
param adminPassword string 

@description('The allowed IP address for RDP access.')
param allowedRdpSourceAddress string

@description('The location of the resource group.')
param location string = resourceGroup().location

@description('Specifies whether to use a custom image or a default image. Select "Yes" for custom image, "No" for default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

@description('The resource ID of the custom image to use if useCustomImage is true.')
param customImageResourceId string = '/subscriptions/8f8bee69-0b24-457d-a9af-3623095b0d78/resourceGroups/shaiknlab2/providers/Microsoft.Compute/galleries/shaikngallery/images/newvmdef/versions/0.0.1'

var useCustomImageBool = useCustomImage == 'Yes' ? true : false 

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'clientVNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.10.0.0/24'
          routeTable: {
            id: routeTable.id
          }
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
      {
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
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2020-11-01' = {
  name: 'clientVMRouteTable'
  location: location
  properties: {
    routes: [
      // {
      //   name: 'routeToFirewall'
      //   properties: {
      //     addressPrefix: '0.0.0.0/0'
      //     nextHopType: 'VirtualAppliance'
      //     nextHopIpAddress: firewall.outputs.firewallIpAddress
      //   }
      // }
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
  name: 'clientVm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
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

output vnetId string = vnet.id
output vnetname string = vnet.name
// output publicIpAddress string = publicIp.properties.ipAddress


