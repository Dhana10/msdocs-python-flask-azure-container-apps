param location string
param name string
@description('Optional Entra object id of the GitHub Actions OIDC identity for AcrPush.')
param deployerPrincipalId string = ''

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

var acrPushRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')

resource pushToAcr 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (length(deployerPrincipalId) > 0) {
  name: guid(registry.id, deployerPrincipalId, acrPushRole)
  scope: registry
  properties: {
    principalId: deployerPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPushRole
  }
}

output loginServer string = registry.properties.loginServer
output registryId string = registry.id
output name string = registry.name
