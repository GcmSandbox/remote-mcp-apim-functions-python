@description('Resource Group')
param resourceGroupName string

var location string = resourceGroup().location
var apimServiceName string = resourceGroupName
var functionAppName string = resourceGroupName
var appServicePlanName string = resourceGroupName
var storageAccountName string = replace(resourceGroupName, '-', '')
var entraApplicationDisplayName string = resourceGroupName
var entraApplicationUniqueName string = resourceGroupName
var logAnalyticsName string = resourceGroupName
var applicationInsightsName string = resourceGroupName

// MCP Client APIM gateway specific variables

var oauth_scopes = 'openid https://graph.microsoft.com/.default'

var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, location))
var tags = { 'azd-env-name': resourceGroupName }
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'

// OAuth APIM service deployment
module apimService '../core/apim/apim.bicep' = {
  name: 'oauthApimService'
  params:{
    apiManagementName: apimServiceName
    appInsightsName: monitoring.outputs.applicationInsightsName
  }
}

module entraApp './entra-app.bicep' = {
  name: 'entraApp'
  params:{
    entraAppUniqueName: entraApplicationUniqueName
    entraAppDisplayName: entraApplicationDisplayName
    apimOauthCallback: '${apimService.outputs.gatewayUrl}/oauth-callback'
    managedIdentityObjectId: apimService.outputs.principalId
  }
}

// Now create the full OAuth API module with all APIM resources
module oauthAPIModule './oauth.bicep' = {
  name: 'oauthAPIModule'
  params: {
    location: location
    entraAppClientId: entraApp.outputs.appId
    entraAppIdentifier: entraApp.outputs.identifierUri
    apimServiceName: apimServiceName
    oauthScopes: oauth_scopes
    functionAppName: functionAppName
  }
  dependsOn: [
    funcApp
  ]
}

// The application backend is a function app
module appServicePlan '../core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  params: {
    name: appServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
  }
}

module funcApp '../core/api.bicep' = {
  name: 'funcApp'
  params: {
    serviceName: 'auth'
    name: functionAppName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    oauthClientId: entraApp.outputs.appId
    oauthIdenifier: entraApp.outputs.identifierUri
  }
}

// Backing storage for Azure functions api
module storage '../core/storage/storage-account.bicep' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    containers: [{name: deploymentStorageContainerName}, {name: 'clients'}]
    publicNetworkAccess: 'Enabled'
  }
}

// // Monitor application with Azure Monitor
module monitoring '../core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
  }
}

var monitoringRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher role ID

// // Allow access from api to application insights using a managed identity
module appInsightsRoleAssignmentFunc '../core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentFunc'
  params: {
    appInsightsName: monitoring.outputs.applicationInsightsName
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: funcApp.outputs.identityId
  }
}

module appInsightsRoleAssignmentApim '../core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentapim'
  params: {
    appInsightsName: monitoring.outputs.applicationInsightsName
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: apimService.outputs.principalId
  }
}


output serverUrl string = apimService.outputs.gatewayUrl
output serverIdentifier string = entraApp.outputs.identifierUri
output appName string = entraApplicationUniqueName
