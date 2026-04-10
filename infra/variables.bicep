@description('Short slug for Azure names: letters and digits only, e.g. restrev.')
param projectSlug string

@allowed([
  'dev'
  'qa'
])
param environment string

var env = toLower(environment)

output containerAppName string = 'ca-${projectSlug}-${env}'
output staticWebAppName string = take('swa-${projectSlug}-${env}-${uniqueString(subscription().subscriptionId, resourceGroup().id, projectSlug, env)}', 60)
output identityName string = 'id-${projectSlug}-${env}'
output logAnalyticsName string = 'log-${projectSlug}-${env}'
output containerEnvName string = 'cae-${projectSlug}-${env}'
