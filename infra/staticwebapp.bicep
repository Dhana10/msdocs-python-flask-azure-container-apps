param location string
param name string
param tags object = {}

resource site 'Microsoft.Web/staticSites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

output name string = site.name
output defaultHostname string = site.properties.defaultHostname
output siteId string = site.id
