@description('Specifies the name of the Azure Storage account.')
param storageAccountName string = 'shaiknstr${uniqueString(resourceGroup().id)}'

@description('Specifies the name of the blob container.')
param containerName string = 'folder'

@description('Specifies the location in which the Azure Storage resources should be deployed.')
param location string = resourceGroup().location

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: sa
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: containerName
}

output storageAccountName string = sa.name
output storageAccountBlobEndpoint string = sa.properties.primaryEndpoints.blob
output containerName string = container.name
output storageAccountId string = sa.id
