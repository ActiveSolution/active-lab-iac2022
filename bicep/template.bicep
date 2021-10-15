param appServicePlanSku string
param location string

var webAppName = 'webapp${uniqueString(resourceGroup().id)}'
var keyVaultName = 'keyvault${uniqueString(resourceGroup().id)}'
var sqlServerName = 'sqlserver${uniqueString(resourceGroup().id)}'
var sqlDbName = 'infradb'
var sqlAdministratorLogin = 'infraadmin'
var sqlAdministratorPassword = 'P${uniqueString(resourceGroup().id, '224F5A8B-51DB-46A3-A7C8-59B0DD584A41')}x!'


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'logAnalytics'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appInsights'
  location: location
  kind: 'web'
  tags: {
    'hidden-link:${webApplication.id}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId:logAnalyticsWorkspace.id
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
        value: 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
      }
    ]
  }
  dependsOn: [
    webApplication
    appInsightsComponents
  ]
}


resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' ={
  name: sqlServerName
  location: location

  properties:{
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
  }

  resource sqlServerDatabase 'databases@2021-02-01-preview' = {
    name: sqlDbName
    location: location
    properties: {
      edition: 'Basic'
    }
  }

  resource sqlServerName_activeDirectory 'administrators@2021-02-01-preview' = {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      login: webApplication.name
      sid: webApplication.identity.principalId
      tenantId: webApplication.identity.tenantId
    }
  }  

  resource sqlServerName_AllowAllWindowsAzureIps 'firewallRules@2020-11-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }  
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: webApplication.identity.principalId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }

  resource keyVaultSecret 'secrets@2021-06-01-preview' = {
    name: 'testSecret'
    properties: {
      value: 'hello from bicep'
    }
  }  
}



resource appServicePlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: 'appServicePlan'
  kind: 'linux'

  location: location
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  properties:{
    reserved: true
  }  
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: webAppName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig:{
      linuxFxVersion:'DOCKER|iacworkshop.azurecr.io/infrawebapp:v1'
      connectionStrings: [
        {
          name: 'infradb'
          connectionString: 'Data Source=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};Authentication=Active Directory Interactive;'
          type: 'SQLAzure'
        }
      ]      
    }
  }
}

output websiteAddress string = 'https://${webApplication.properties.defaultHostName}/'
