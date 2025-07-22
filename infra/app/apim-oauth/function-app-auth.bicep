extension microsoftGraphV1

@description('The name of the Function App')
param functionAppName string

@description('The Function App Client ID from the dedicated app registration')
param functionAppClientId string

@description('The Function App Identifier from the dedicated app registration') 
param functionAppIdentifier string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

// Get reference to the Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

// Configure Easy Auth on the Function App with dedicated app registration
resource functionAppAuthSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: functionApp
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
          clientId: functionAppClientId
        }
        validation: {
          allowedAudiences: [
            functionAppClientId
            functionAppIdentifier
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

// Outputs
output functionAppClientId string = functionAppClientId
output functionAppTenantId string = tenantId
