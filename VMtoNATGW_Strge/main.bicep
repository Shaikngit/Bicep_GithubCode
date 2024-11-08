@description('Location of the resource group') 
param location string = resourceGroup().location

@description('Admin Password for the VMs and SQL Server')
@secure()
param adminpassword string

param adminusername string
param allowedRdpSourceAddress string

@description('Specifies whether to use a custom image or a default image. Select "Yes" for custom image, "No" for default image.')
@allowed([
  'Yes'
  'No'
])
param useCustomImage string = 'No'

module windowsVM './clientvm/client.bicep' = {
  name: 'windowsVMDeployment'
  params: {
    adminUsername: adminusername
    adminPassword: adminpassword
    location: location
    allowedRdpSourceAddress: allowedRdpSourceAddress
    useCustomImage: useCustomImage
    
  }
}

module storageAccount './simplestorage/storage.bicep' = {
  name: 'storageAccountDeployment'
  params: {
     location: location
     }
}
