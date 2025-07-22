extension microsoftGraphV1

@description('The name of the Entra application')
param entraAppUniqueName string

@description('The display name of the Entra application')
param entraAppDisplayName string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

@description('The OAuth callback URL for the API Management service')
param apimOauthCallback string

@description('The principle id of the user-assigned managed identity')
param userAssignedIdentityPrincipleId string

@description('The Function App client ID to request access to')
param functionAppClientId string

var loginEndpoint = environment().authentication.loginEndpoint
var issuer = '${loginEndpoint}${tenantId}/v2.0'

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
    {
      resourceAppId: functionAppClientId
      resourceAccess: [
        {
          id: '44444444-4444-4444-4444-444444444444' // user_impersonation scope from Function App
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
    description: 'Trust the user-assigned MI as a credential for the app'
    audiences: [
       'api://AzureADTokenExchange'
    ]
    issuer: issuer
    subject: userAssignedIdentityPrincipleId
  }
}

// Outputs
output entraAppId string = entraApp.appId
output entraAppTenantId string = tenantId
