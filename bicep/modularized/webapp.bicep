param appServicePlanId string
param keyVaultName string
param sqlServerFQDN string
param sqlDbName string
param logAnalyticsWorkspaceId string

var webAppName = 'webapp${uniqueString(resourceGroup().id)}'

resource webApplication 'Microsoft.Web/sites@2018-11-01' = {
  name: webAppName
  location: resourceGroup().location
  identity:{
    type: 'SystemAssigned'
  }
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig:{
      linuxFxVersion:'DOCKER|iacworkshop.azurecr.io/infrawebapp:v1'
      appSettings:[
      ]
      connectionStrings: [
        {
          name: 'infradb'
          connectionString: 'Data Source=tcp:${sqlServerFQDN},1433;Initial Catalog=${sqlDbName};Authentication=Active Directory Interactive;'
          type: 'SQLAzure'
        }
      ]      
    }
  }
}

resource appInsightsComponents 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: 'appInsights'
  location: resourceGroup().location
  kind: 'web'
  tags: {
    'hidden-link:${webApplication.id}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId:logAnalyticsWorkspaceId
  }
}

resource webAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  name: '${webApplication.name}/web'
  properties: {
    appSettings: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        value: reference(appInsightsComponents.id).InstrumentationKey
      }
      {
        name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
        value: '~2'
      }
      {
        name: 'XDT_MicrosoftApplicationInsights_Mode'
        value: 'recommended'
      }
      {
        name: 'keyVaultName'
        value: keyVaultName
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_URL'
        value: 'https://iacworkshop.azurecr.io'
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_USERNAME'
        value: 'iacworkshop'
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
        value: 'XXXXXXXXXXXXXXXXXXXX'
      }
    ]
  }
  dependsOn: [
    webApplication
    appInsightsComponents
  ]
}

output webApplicationName string = webApplication.name
output webApplicationPrincipalId string = webApplication.identity.principalId
output webApplicationTenantId string = webApplication.identity.tenantId
output webApplicationDefaultHostName string = webApplication.properties.defaultHostName
