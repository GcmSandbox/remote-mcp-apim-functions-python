extension microsoftGraphV1

@description('The name of the Function App')
param functionAppName string

@description('The OAuth Client ID from the main OAuth app')
param oauthClientId string

@description('The OAuth Identifier from the main OAuth app')
param oauthIdentifier string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

// Get reference to the Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

//var loginEndpoint = environment().authentication.loginEndpoint
//var issuer = '${loginEndpoint}${tenantId}/v2.0'

// Configure Easy Auth on the Function App after app creation
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
          //openIdIssuer: issuer
          clientId: oauthClientId
        }
        validation: {
          allowedAudiences: [
            oauthClientId
            oauthIdentifier
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
output functionAppClientId string = oauthClientId
output functionAppTenantId string = tenantId
