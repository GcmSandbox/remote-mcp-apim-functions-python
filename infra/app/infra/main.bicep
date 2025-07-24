targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

param authServerName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

// module main '../../main.bicep' = {
//   name: 'main'
//   params: {
//     environmentName: environmentName
//     location: location
//   }
// }

var tags = { 'azd-env-name': environmentName }

var appResourceGroupName = 'gcmdev-${environmentName}app-dev'
// Organize resources in a resource group
resource appResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: appResourceGroupName
  location: location
  tags: tags
}

resource authResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: authServerName
}

resource authServer 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: authServerName
  scope: authResourceGroup
}

extension microsoftGraphV1
resource authEntraApp 'Microsoft.Graph/applications@v1.0' existing = {  
  uniqueName: authServerName
}

// OAuth APIM service deployment
module mcpApp '../app.bicep' = {
  name: 'mcpApp'
  scope: appResourceGroup
  params:{
    resourceGroupName: appResourceGroupName
    authServerUrl: authServer.properties.gatewayUrl
    authServerIdentifier: authEntraApp.identifierUris[0]
  }
}
