param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param runtimeName string 
param runtimeVersion string 
param serviceName string
param storageAccountName string
param deploymentStorageContainerName string
param virtualNetworkSubnetId string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param oauthClientId string = ''
param oauthIdenifier string = ''

module api '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityType: 'SystemAssigned'
    appSettings: appSettings
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    storageAccountName: storageAccountName
    deploymentStorageContainerName: deploymentStorageContainerName
    virtualNetworkSubnetId: virtualNetworkSubnetId
    instanceMemoryMB: instanceMemoryMB 
    maximumInstanceCount: maximumInstanceCount
    oauthClientId: oauthClientId
    oauthIdenifier: oauthIdenifier
  }
}

//output SERVICE_API_NAME string = api.outputs.name
//output SERVICE_API_IDENTITY_PRINCIPAL_ID string = api.outputs.identityPrincipalId
//output SERVICE_API_URI string = api.outputs.uri
output identityId string = api.outputs.identityPrincipalId
