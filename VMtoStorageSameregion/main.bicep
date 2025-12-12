@description('Location of the resource group') 
param location string = resourceGroup().location

@description('Admin Password for the VMs and SQL Server')
@secure()
param adminpassword string

param adminusername string

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

module windowsVM './simplewindows/client.bicep' = {
  name: 'windowsVMDeployment'
  params: {
    adminUsername: adminusername
    adminPassword: adminpassword
    location: location
    useCustomImage: useCustomImage
    vmSizeOption: vmSizeOption
  }
}

module storageAccount './simplestorage/storage.bicep' = {
  name: 'storageAccountDeployment'
  params: {
     location: location
     }
}

// Storage Blob Data Contributor role definition ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// RBAC Role Assignment - Grant VM's managed identity Storage Blob Data Contributor role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'vm-storage-blob-contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: windowsVM.outputs.vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output bastionName string = windowsVM.outputs.bastionName
output vmName string = windowsVM.outputs.vmName
output vmPrivateIp string = windowsVM.outputs.vmPrivateIp
output vmPublicIp string = windowsVM.outputs.vmPublicIp
output vmPrincipalId string = windowsVM.outputs.vmPrincipalId
output storageAccountName string = storageAccount.outputs.storageAccountName
output storageBlobEndpoint string = storageAccount.outputs.storageAccountBlobEndpoint
output containerName string = storageAccount.outputs.containerName
output roleAssignmentInfo string = 'VM has Storage Blob Data Contributor role on storage account'
