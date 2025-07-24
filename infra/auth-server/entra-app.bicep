extension microsoftGraphV1

@description('The name of the Entra application')
param entraAppUniqueName string

@description('The display name of the Entra application')
param entraAppDisplayName string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

@description('The OAuth callback URL for the API Management service')
param apimOauthCallback string

@description('The principal id of the managed identity')
param managedIdentityObjectId string

// @description('The Function App name')
// param functionAppName string

var loginEndpoint = environment().authentication.loginEndpoint
var issuer = '${loginEndpoint}${tenantId}/v2.0'

// resource functionApp 'Microsoft.Graph/applications@v1.0' existing = {
//   uniqueName: functionAppName
// }

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: entraAppDisplayName
  uniqueName: entraAppUniqueName
  web: {
    redirectUris: [
      apimOauthCallback
    ]
  }
  requiredResourceAccess: [
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
          type: 'Scope'
        }
      ]
    }
  ]
  identifierUris: [
    'api://${entraAppUniqueName}/${tenant().tenantId}'
  ]
  api: {
    oauth2PermissionScopes: [
      {
        id: '00000000-0000-0000-0000-000000000001'
        adminConsentDescription: 'Allow the application to access the MCP API on behalf of the signed-in user'
        adminConsentDisplayName: 'Access MCP API'
        userConsentDescription: 'Allow the application to access the MCP API on your behalf'
        userConsentDisplayName: 'Access MCP API'
        value: 'user_impersonation'
        type: 'User'
        isEnabled: true
      }
    ]
  }

  resource fic 'federatedIdentityCredentials@v1.0' = {
    name: '${entraApp.uniqueName}/msiAsFic'
    description: 'Trust the Managed Identity as a credential for the app'
    audiences: [
       'api://AzureADTokenExchange'
    ]
    issuer: issuer
    subject: managedIdentityObjectId
  }
}

// Create a service principal for the application
resource functionServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: entraApp.appId
  displayName: entraAppDisplayName
}

// Outputs
output appId string = entraApp.appId
output identifierUri string = entraApp.identifierUris[0]
