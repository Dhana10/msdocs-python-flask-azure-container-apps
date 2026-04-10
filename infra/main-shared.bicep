targetScope = 'resourceGroup'

param location string = resourceGroup().location

@minLength(5)
@maxLength(50)
@description('Globally unique ACR name (alphanumeric only).')
param acrName string

@description('Optional object id of the GitHub OIDC service principal for AcrPush.')
param deployerPrincipalId string = ''

module registry 'acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    name: acrName
    deployerPrincipalId: deployerPrincipalId
  }
}

output acrName string = registry.outputs.name
output acrLoginServer string = registry.outputs.loginServer
output acrId string = registry.outputs.registryId
