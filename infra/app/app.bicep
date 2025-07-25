@description('Resource Group')
param resourceGroupName string

param authServerUrl string
param authServerIdentifier string

var location string = resourceGroup().location
var apimServiceName string = resourceGroupName
var functionAppName string = resourceGroupName
var appServicePlanName string = resourceGroupName
var storageAccountName string = replace(resourceGroupName, '-', '')
var entraApplicationDisplayName string = resourceGroupName
var entraApplicationUniqueName string = resourceGroupName
var logAnalyticsName string = resourceGroupName
var applicationInsightsName string = resourceGroupName

var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, location))
var tags = { 'azd-env-name': resourceGroupName }
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'

// OAuth APIM service deployment
module apimService '../core/apim/apim.bicep' = {
  name: 'apimService'
  params:{
    apiManagementName: apimServiceName
    appInsightsName: monitoring.outputs.applicationInsightsName
  }
}

// Function App Entra registration (now can reference OAuth app)
module entraApp './function-entra-app.bicep' = {
  name: 'entraApp'
  params: {
    functionAppUniqueName: entraApplicationUniqueName
    functionAppDisplayName: entraApplicationDisplayName
    functionAppUrl: 'https://${functionAppName}.azurewebsites.net'
  }
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

module app '../core/api.bicep' = {
  name: 'app'
  params: {
    serviceName: 'app'
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

// MCP server API endpoints
module mcpApiModule './mcp-api.bicep' = {
  name: 'mcpApiModule'
  params: {
    apimServiceName: apimServiceName
    functionAppName: functionAppName
    entraIdentifier: entraApp.outputs.identifierUri
    authServerUrl: authServerUrl
    authServerIdentifier: authServerIdentifier
  }
  dependsOn:[
    apimService
    app
  ]
}

// Backing storage for Azure functions api
module storage '../core/storage/storage-account.bicep' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    containers: [{name: deploymentStorageContainerName}, {name: 'snippets'}]
    publicNetworkAccess: 'Enabled'
  }
}

// Monitor application with Azure Monitor
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

// Allow access from api to application insights using a managed identity
module appInsightsRoleAssignmentFunc '../core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentFunc'
  params: {
    appInsightsName: monitoring.outputs.applicationInsightsName
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: app.outputs.identityId
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


output appName string = entraApplicationUniqueName
