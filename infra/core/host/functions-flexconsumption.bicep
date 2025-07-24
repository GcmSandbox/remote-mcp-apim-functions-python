param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
param applicationInsightsName string = ''
param appServicePlanId string
param storageAccountName string
param virtualNetworkSubnetId string = ''
@allowed(['SystemAssigned', 'UserAssigned'])
param identityType string

// Runtime Properties
@allowed([
  'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
@allowed(['3.10', '3.11', '7.4', '8.0', '10', '11', '17', '20'])
param runtimeVersion string
param kind string = 'functionapp,linux'

// Microsoft.Web/sites/config
param appSettings object = {}
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param deploymentStorageContainerName string

param oauthClientId string = ''
param oauthIdenifier string = ''

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${stg.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${stg.listKeys().keys[0].value}'

resource functions 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  identity: {
    type: identityType
  }
  properties: {
    serverFarmId: appServicePlanId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${stg.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'AzureWebJobsStorage'
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
    virtualNetworkSubnetId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
  }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(appSettings,
      {
        AzureWebJobsStorage: storageConnectionString
      },
      !empty(applicationInsightsName) ? {
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      } : {}
    )
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// Configure Easy Auth on the Function App with dedicated app registration
resource functionAppAuthSettings 'Microsoft.Web/sites/config@2023-12-01' = if (!empty(oauthClientId)){
  parent: functions
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
      excludedPaths: [
        '/api/healthcheck'
      ]
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/'
          clientId: oauthClientId
        }
        validation: {          
          allowedAudiences: [
            oauthClientId
            oauthIdenifier
          ]
          // Allow any authenticated user with a valid token for this app
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

output name string = functions.name
output uri string = 'https://${functions.properties.defaultHostName}'
output identityPrincipalId string = identityType == 'SystemAssigned' ? functions.identity.principalId : ''
