/**
 * @module apim-v1
 * @description This module defines the Azure API Management (APIM) resources using Bicep.
 * It includes configurations for creating and managing APIM instance.
 * This is version 1 (v1) of the APIM Bicep module.
 */

// ------------------
//    PARAMETERS
// ------------------


@description('The name of the API Management instance. Defaults to "apim-<resourceSuffix>".')
param apiManagementName string

@description('The location of the API Management instance. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The email address of the publisher. Defaults to "noreply@microsoft.com".')
param publisherEmail string = 'noreply@microsoft.com'

@description('The name of the publisher. Defaults to "Microsoft".')
param publisherName string = 'Microsoft'

@description('Name of the APIM Logger')
param apimLoggerName string = 'apim-logger'

@description('Description of the APIM Logger')
param apimLoggerDescription string  = 'APIM Logger for OpenAI API'

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Basicv2'

@description('The name for Application Insights')
param appInsightsName string = ''

param bytesToLog object = { frontEndRequest: 8192, backEndRequest: 8192, frontEndResponse: 8192, backendResponse: 8192 }

// ------------------
//    VARIABLES
// ------------------


// ------------------
//    RESOURCES
// ------------------

// https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(appInsightsName)) {
  name: appInsightsName
}

// Create a logger only if we have an App Insights ID and instrumentation key.
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (!empty(appInsightsName)) {
  name: apimLoggerName
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    description: apimLoggerDescription
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: appInsights.id
  }
}

resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = if (!empty(appInsightsName)) {
  parent: apimService
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apimLogger.id
    logClientIp: true
    verbosity: 'Information'
    backend: {
      request: {
        body: {
          bytes: bytesToLog.backEndRequest
        }
      }
      response: {
        body: {
          bytes: bytesToLog.backendResponse
        }
      }
    }
    frontend: {
      request: {
        body: {
          bytes: bytesToLog.frontEndRequest
        }
      }
      response: {
        body: {
          bytes: bytesToLog.frontEndResponse
        }
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output id string = apimService.id
output name string = apimService.name
output principalId string = apimService.identity.principalId
output gatewayUrl string = apimService.properties.gatewayUrl
