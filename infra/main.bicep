targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string


@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param prefix string
param suffix string

var tags = { 'azd-env-name': environmentName }

var authResourceGroupName = '${prefix}-${environmentName}auth-${suffix}'
// Organize resources in a resource group
resource authResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: authResourceGroupName
  location: location
  tags: tags
}

// OAuth APIM service deployment
module authServer './auth-server/auth-server.bicep' = {
  name: 'authServer'
  scope: authResourceGroup
  params:{
    resourceGroupName: authResourceGroupName
  }
}

var appResourceGroupName = '${prefix}-${environmentName}app-${suffix}'
// Organize resources in a resource group
resource appResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: appResourceGroupName
  location: location
  tags: tags
}

// OAuth APIM service deployment
module mcpApp './app/app.bicep' = {
  name: 'mcpApp'
  scope: appResourceGroup
  params:{
    resourceGroupName: appResourceGroupName
    authServerUrl: authServer.outputs.serverUrl
    authServerIdentifier: authServer.outputs.serverIdentifier
  }
}
