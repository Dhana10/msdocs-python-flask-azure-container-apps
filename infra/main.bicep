targetScope = 'resourceGroup'

@description('Short slug for resource names (letters/digits only, e.g. restrev).')
param projectSlug string = 'restrev'

param location string = resourceGroup().location

@description('ACR name — globally unique, alphanumeric only, 5-50 chars.')
@minLength(5)
@maxLength(50)
param acrName string

@description('Entra object ID of the GitHub OIDC service principal. Grants AcrPush so CI can push images.')
param deployerPrincipalId string = ''

@secure()
param flaskSecretKey string

@description('Initial container image. The deploy workflow overwrites this on every push.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

param tags object = {}

// All resources land in a single resource group — simple and cost-effective.
var identityName    = 'id-${projectSlug}'
var logAnalyticsName = 'log-${projectSlug}'
var containerEnvName = 'cae-${projectSlug}'
var containerAppName = 'ca-${projectSlug}'

// ── Azure Container Registry ─────────────────────────────────────────────────
module acr 'acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    name: acrName
    deployerPrincipalId: deployerPrincipalId
  }
}

// ── Managed Identity (used by the Container App to pull images from ACR) ─────
module managedId 'identity.bicep' = {
  name: 'managed-identity'
  params: {
    location: location
    name: identityName
  }
}

// ── AcrPull role for the managed identity ────────────────────────────────────
module acrPull 'acr-role.bicep' = {
  name: 'acr-pull'
  params: {
    acrName: acrName
    principalId: managedId.outputs.principalId
  }
  dependsOn: [acr, managedId]
}

// ── Container App + Log Analytics ────────────────────────────────────────────
module cae 'containerapp.bicep' = {
  name: 'container-app'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    containerEnvName: containerEnvName
    containerAppName: containerAppName
    tags: tags
    managedIdentityId: managedId.outputs.id
    acrLoginServer: acr.outputs.loginServer
    containerImage: containerImage
    flaskSecretKey: flaskSecretKey
  }
  dependsOn: [acrPull]
}

output containerAppName string = cae.outputs.containerAppNameOut
output containerAppUrl  string = 'https://${cae.outputs.containerAppFqdn}'
output acrLoginServer   string = acr.outputs.loginServer
