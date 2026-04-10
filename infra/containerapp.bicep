param location string
param logAnalyticsName string
param containerEnvName string
param containerAppName string
param tags object = {}

param managedIdentityId string

@description('ACR login server hostname, e.g. myregistry.azurecr.io')
param acrLoginServer string
param containerImage string

@secure()
param flaskSecretKey string

@description('Comma-separated CORS origins (leave empty when frontend is served by Flask itself).')
param corsOrigins string = ''

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
        transport: 'Auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'flask-secret-key'
          value: flaskSecretKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'flask-api'
          image: containerImage
          env: [
            { name: 'RUNNING_IN_PRODUCTION', value: '1' }
            { name: 'AZURE_SECRET_KEY',       secretRef: 'flask-secret-key' }
            { name: 'CORS_ORIGINS',            value: corsOrigins }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/api/health'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 40
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/api/health'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 15
              periodSeconds: 15
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
      }
    }
  }
}

output containerAppFqdn    string = containerApp.properties.configuration.ingress.fqdn
output containerAppNameOut string = containerApp.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
