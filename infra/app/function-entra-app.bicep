extension microsoftGraphV1

@description('The name of the Function App Entra application')
param functionAppUniqueName string

@description('The display name of the Function App Entra application')
param functionAppDisplayName string

@description('The Function App URL for authentication')
param functionAppUrl string

resource functionEntraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: functionAppDisplayName
  uniqueName: functionAppUniqueName
  web: {
    redirectUris: [
      '${functionAppUrl}/.auth/login/aad/callback'
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
    'api://${functionAppUniqueName}/${tenant().tenantId}'
  ]
  api: {
    oauth2PermissionScopes: [
      {
        id: '44444444-4444-4444-4444-444444444444'
        adminConsentDescription: 'Allow the application to access the Function App on behalf of the signed-in user'
        adminConsentDisplayName: 'Access Function App'
        userConsentDescription: 'Allow the application to access the Function App on your behalf'
        userConsentDisplayName: 'Access Function App'
        value: 'user_impersonation'
        type: 'User'
        isEnabled: true
      }
    ]
  }
}

// Create a service principal for the application
resource functionServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: functionEntraApp.appId
  displayName: functionAppDisplayName
}

// Outputs
output appId string = functionEntraApp.appId
output identifierUri string = 'api://${functionAppUniqueName}/${tenant().tenantId}'
