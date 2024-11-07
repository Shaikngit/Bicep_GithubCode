@description('Specifies the location for all the resources.')
param location string = resourceGroup().location

@description('Specifies the name of the virtual network hosting the virtual machine.')
param virtualNetworkName string = 'UbuntuVnet'

@description('Specifies the address prefix of the virtual network hosting the virtual machine.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Specifies the name of the subnet hosting the virtual machine.')
param subnetName string = 'DefaultSubnet'

@description('Specifies the address prefix of the subnet hosting the virtual machine.')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Specifies the globally unique DNS Name for the ADLS Gen 2 storage account.')
param adlsStorageAccountName string = 'adls${uniqueString(resourceGroup().id)}'

@description('Specifies the globally unique name for the storage account used to store the boot diagnostics logs of the virtual machine.')
param blobStorageAccountName string = 'boot${uniqueString(resourceGroup().id)}'

@description('Specifies the name of the virtual machine.')
param vmName string = 'TestVm'

@description('Specifies the size of the virtual machine.')
param vmSize string = 'Standard_D4s_v3'

@description('Specifies the image publisher of the disk image used to create the virtual machine.')
param imagePublisher string = 'Canonical'

@description('Specifies the offer of the platform image or marketplace image used to create the virtual machine.')
param imageOffer string = 'UbuntuServer'

@description('Specifies the Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
param imageSku string = '18.04-LTS'

@description('Specifies the type of authentication when accessing the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('Specifies the name of the administrator account of the virtual machine.')
param adminUsername string = 'azadmin'

@description('Specifies the SSH Key or password for the virtual machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Specifies the storage account type for OS and data disk.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param diskStorageAccounType string = 'Premium_LRS'

@description('Specifies the number of data disks of the virtual machine.')
@minValue(0)
@maxValue(64)
param numDataDisks int = 1

@description('Specifies the size in GB of the OS disk of the VM.')
param osDiskSize int = 50

@description('Specifies the size in GB of the OS disk of the virtual machine.')
param dataDiskSize int = 50

@description('Specifies the caching requirements for the data disks.')
param dataDiskCaching string = 'ReadWrite'

@description('Specifies the base URI where artifacts required by this template are located including a trailing \'/\'')
//  param _artifactsLocation string = deployment().properties.templateLink.uri
param scriptFileUri string

// @description('Specifies the sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
// @secure()
// param _artifactsLocationSasToken string = ''

@description('The name of the script to download from the URI specified by the scriptFilePath parameter.')
param scriptFileName string = 'nslookup.sh'

@description('Specifies whether to deploy a Log Analytics workspace to monitor the health and performance of the virtual machine.')
param deployLogAnalytics bool = true

@description('Specifies the globally unique name of the Log Analytics workspace.')
param workspaceName string

@description('Specifies the SKU of the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
  'Standard'
  'Premium'
])
param workspaceSku string = 'PerGB2018'

@description('Specifies the name of the private link to the storage account.')
param adlsStorageAccountPrivateEndpointName string = 'AdlsStorageAccountPrivateEndpoint'

@description('Specifies the name of the private link to the boot diagnostics storage account.')
param blobStorageAccountPrivateEndpointName string = 'BlobStorageAccountPrivateEndpoint'

var nicName = '${vmName}Nic'
var nsgName = '${subnetName}Nsg'
var publicIPAddressName = '${vmName}PublicIp'
var publicIPAddressType = 'Dynamic'
var workspaceId = workspace.id
var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var vnetId = virtualNetwork.id
var nsgId = nsg.id
//var scriptFileUri = uri(_artifactsLocation, 'scripts/${scriptFileName}${_artifactsLocationSasToken}')
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
  provisionVMAgent: true
}
var adlsStorageAccountId = adlsStorageAccount.id
var blobStorageAccountId = blobStorageAccount.id
var adlsPublicDNSZoneForwarder = '.dfs.${environment().suffixes.storage}'
var blobPublicDNSZoneForwarder = '.blob.${environment().suffixes.storage}'
var adlsPrivateDnsZoneName = 'privatelink${adlsPublicDNSZoneForwarder}'
var blobPrivateDnsZoneName = 'privatelink${blobPublicDNSZoneForwarder}'
var adlsPrivateDnsZoneId = adlsPrivateDnsZone.id
var blobPrivateDnsZoneId = blobPrivateDnsZone.id
var adlsServicePrimaryEndpoint = '${adlsStorageAccountName}${adlsPublicDNSZoneForwarder}'
var blobServicePrimaryEndpoint = '${blobStorageAccountName}${blobPublicDNSZoneForwarder}'
var adlsStorageAccountPrivateEndpointGroupName = 'dfs'
var blobStorageAccountPrivateEndpointGroupName = 'blob'
var adlsPrivateDnsZoneGroupname = '${adlsStorageAccountPrivateEndpointName}/${adlsStorageAccountPrivateEndpointGroupName}PrivateDnsZoneGroup'
var blobPrivateDnsZoneGroupname = '${blobStorageAccountPrivateEndpointName}/${blobStorageAccountPrivateEndpointGroupName}PrivateDnsZoneGroup'

resource adlsStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: adlsStorageAccountName
  location: location
  sku: {
    name: 'Standard_RAGRS'
  }
  kind: 'StorageV2'
}

resource blobStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: blobStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-04-01' = {
  name: publicIPAddressName
  location: location
  properties: {
    publicIPAllocationMethod: publicIPAddressType
    dnsSettings: {
      domainNameLabel: '${toLower(vmName)}${uniqueString(resourceGroup().id)}'
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-08-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSshInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
  dependsOn: [
        virtualNetwork
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2019-12-01' = {
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
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: osDiskSize
        managedDisk: {
          storageAccountType: diskStorageAccounType
        }
      }
      dataDisks: [
        for j in range(0, numDataDisks): {
          caching: dataDiskCaching
          diskSizeGB: dataDiskSize
          lun: j
          name: '${vmName}-DataDisk${j}'
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: diskStorageAccounType
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(blobStorageAccountId).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    adlsStorageAccountPrivateEndpoint
    blobStorageAccountPrivateEndpoint
      ]
}

resource vmName_CustomScript 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  parent: vm
  name: 'CustomScript'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
      timestamp: 123456789
       fileUris: [
         scriptFileUri
       ]
    }
    protectedSettings: {
      commandToExecute: 'bash ${scriptFileName} ${adlsServicePrimaryEndpoint} ${blobServicePrimaryEndpoint}'
    }
  }
}

resource vmName_LogAnalytics 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  parent: vm
  name: 'LogAnalytics'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'OmsAgentForLinux'
    typeHandlerVersion: '1.12'
    settings: {
      workspaceId: reference(workspaceId, '2020-03-01-preview').customerId
      stopOnMultipleConnections: false
    }
    protectedSettings: {
      workspaceKey: listKeys(workspaceId, '2020-03-01-preview').primarySharedKey
    }
  }
  dependsOn: [
    vmName_CustomScript
  ]
}

resource vmName_DependencyAgent 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  parent: vm
  name: 'DependencyAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentLinux'
    typeHandlerVersion: '9.10'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    workspace
    vmName_CustomScript
    vmName_LogAnalytics
  ]
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = if (deployLogAnalytics) {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: workspaceSku
    }
  }
}

resource workspaceName_Kern 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'Kern'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'kern'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
    ]
  }
}

resource workspaceName_Syslog 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'Syslog'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'syslog'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
    ]
  }
}

resource workspaceName_User 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'User'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'user'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
    ]
  }
}

resource workspaceName_SampleSyslogCollection1 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'SampleSyslogCollection1'
  kind: 'LinuxSyslogCollection'
  properties: {
    state: 'Enabled'
  }

}

resource workspaceName_DiskPerfCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'DiskPerfCounters'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: '% Used Inodes'
      }
      {
        counterName: 'Free Megabytes'
      }
      {
        counterName: '% Used Space'
      }
      {
        counterName: 'Disk Transfers/sec'
      }
      {
        counterName: 'Disk Reads/sec'
      }
      {
        counterName: 'Disk Writes/sec'
      }
      {
        counterName: 'Disk Read Bytes/sec'
      }
      {
        counterName: 'Disk Write Bytes/sec'
      }
    ]
    objectName: 'Logical Disk'
    instanceName: '*'
    intervalSeconds: 10
  }
}

resource workspaceName_ProcessorPerfCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'ProcessorPerfCounters'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: '% Processor Time'
      }
      {
        counterName: '% User Time'
      }
      {
        counterName: '% Privileged Time'
      }
      {
        counterName: '% IO Wait Time'
      }
      {
        counterName: '% Idle Time'
      }
      {
        counterName: '% Interrupt Time'
      }
    ]
    objectName: 'Processor'
    instanceName: '*'
    intervalSeconds: 10
  }
}

resource workspaceName_ProcessPerfCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'ProcessPerfCounters'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: '% User Time'
      }
      {
        counterName: '% Privileged Time'
      }
      {
        counterName: 'Used Memory'
      }
      {
        counterName: 'Virtual Shared Memory'
      }
    ]
    objectName: 'Process'
    instanceName: '*'
    intervalSeconds: 10
  }
}

resource workspaceName_SystemPerfCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'SystemPerfCounters'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: 'Processes'
      }
    ]
    objectName: 'System'
    instanceName: '*'
    intervalSeconds: 10
  }
}

resource workspaceName_NetworkPerfCounters 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'NetworkPerfCounters'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: 'Total Bytes Transmitted'
      }
      {
        counterName: 'Total Bytes Received'
      }
      {
        counterName: 'Total Bytes'
      }
      {
        counterName: 'Total Packets Transmitted'
      }
      {
        counterName: 'Total Packets Received'
      }
      {
        counterName: 'Total Rx Errors'
      }
      {
        counterName: 'Total Tx Errors'
      }
      {
        counterName: 'Total Collisions'
      }
    ]
    objectName: 'Network'
    instanceName: '*'
    intervalSeconds: 10
  }

}

resource workspaceName_MemorydataSources 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'MemorydataSources'
  kind: 'LinuxPerformanceObject'
  properties: {
    performanceCounters: [
      {
        counterName: 'Available MBytes Memory'
      }
      {
        counterName: '% Available Memory'
      }
      {
        counterName: 'Used Memory MBytes'
      }
      {
        counterName: '% Used Memory'
      }
    ]
    objectName: 'Memory'
    instanceName: '*'
    intervalSeconds: 10
  }
}

resource workspaceName_SampleLinuxPerfCollection1 'Microsoft.OperationalInsights/workspaces/dataSources@2020-03-01-preview' = if (deployLogAnalytics) {
  parent: workspace
  name: 'SampleLinuxPerfCollection1'
  kind: 'LinuxPerformanceCollection'
  properties: {
    state: 'Enabled'
  }
}

resource adlsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: adlsPrivateDnsZoneName
  location: 'global'
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: blobPrivateDnsZoneName
  location: 'global'
}

resource adlsPrivateDnsZoneName_link_to_virtualNetwork 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: adlsPrivateDnsZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource blobPrivateDnsZoneName_link_to_virtualNetwork 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: blobPrivateDnsZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource adlsStorageAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-04-01' = {
  name: adlsStorageAccountPrivateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: adlsStorageAccountPrivateEndpointName
        properties: {
          privateLinkServiceId: adlsStorageAccountId
          groupIds: [
            adlsStorageAccountPrivateEndpointGroupName
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
    customDnsConfigs: [
      {
        fqdn: '${adlsStorageAccountName}${adlsPublicDNSZoneForwarder}'
      }
    ]
  }
}

resource blobStorageAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-04-01' = {
  name: blobStorageAccountPrivateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: blobStorageAccountPrivateEndpointName
        properties: {
          privateLinkServiceId: blobStorageAccountId
          groupIds: [
            blobStorageAccountPrivateEndpointGroupName
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
    customDnsConfigs: [
      {
        fqdn: '${blobStorageAccountName}${blobPublicDNSZoneForwarder}'
      }
    ]
  }
}

resource adlsPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = {
  name: adlsPrivateDnsZoneGroupname
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: adlsPrivateDnsZoneId
        }
      }
    ]
  }
}

resource blobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = {
  name: blobPrivateDnsZoneGroupname
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: blobPrivateDnsZoneId
        }
      }
    ]
  }
}

output adlsStorageAccountPrivateEndpoint object = adlsStorageAccountPrivateEndpoint
output blobStorageAccountPrivateEndpoint object = blobStorageAccountPrivateEndpoint
output adlsStorageAccount object = adlsStorageAccount
output blobStorageAccount object = blobStorageAccount
output adminUsername string = adminUsername
output workspaceName string = workspaceName
// output scriptFileUri string = scriptFileUri
output environment object = environment()
