// @description('The base URI where artifacts required by this template are located.')
// param _artifactsLocation string = 'https://mystrarkis2024.blob.core.windows.net/blob/'

// @description('The sasToken required to access _artifactsLocation when they\'re located in a storage account with private access.')
// @secure()
// param _artifactsLocationSasToken string

@description('Specifies the base URI where artifacts required by this template are located including a SAS Token for install_nginx.sh')
//  param _artifactsLocation string = deployment().properties.templateLink.uri
param scriptFileUri string


@description('VM Name')
param vmName string = 'VM'

@description('VM Size')
param vmSize string = 'Standard_D2_v3'

@description('Administrator name')
param adminUsername string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

var vnetName = 'vnet'
var vNetAddressSpace = '10.0.0.0/16'
var subnetName = 'subnet01'
var subnetAdressPrefix = '10.0.0.0/24'
var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
var asgName = 'webServersAsg'
var asgId = asg.id
var nsgName = 'webNsg'
var nsgId = nsg.id
var pipName = 'webServerPip'
var pipId = pip.id
var imageInfo = {
  publisher: 'OpenLogic'
  offer: 'CentOS'
  sku: '6.9'
  version: 'latest'
}
var vmStorageType = 'StandardSSD_LRS'
// var scriptUrl = uri(_artifactsLocation, 'install_nginx.sh${_artifactsLocationSasToken}')
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

resource asg 'Microsoft.Network/applicationSecurityGroups@2020-05-01' = {
  name: asgName
  location: location
  properties: {}
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpAll'
        properties: {
          description: 'Allow http traffic to web servers'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
          protocol: 'Tcp'
          destinationPortRange: '80'
          destinationApplicationSecurityGroups: [
            {
              id: asgId
            }
          ]
        }
      }
      {
        name: 'AllowSshAll'
        properties: {
          description: 'Allow SSH traffic to web servers'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 200
          protocol: 'Tcp'
          destinationPortRange: '22'
          destinationApplicationSecurityGroups: [
            {
              id: asgId
            }
          ]
        }
      }
    ]
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAdressPrefix
          networkSecurityGroup: {
            id: nsgId
          }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vmName_NIC 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: '${vmName}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipId
          }
          subnet: {
            id: subnetId
          }
          applicationSecurityGroups: [
            {
              id: asgId
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    vNet
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    storageProfile: {
      imageReference: imageInfo
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: vmStorageType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmName_NIC.id
        }
      ]
    }
  }
}

resource vmName_linuxconfig 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vm
  name: 'linuxconfig'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        scriptFileUri
      ]
      commandToExecute: 'sh install_nginx.sh'
    }
  }
}
