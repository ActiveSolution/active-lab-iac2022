param appServicePlanSku string


var keyVaultName = 'keyvault${uniqueString(resourceGroup().id)}'
var sqlServerName = 'sqlserver${uniqueString(resourceGroup().id)}'
var sqlDbName = 'infradb'
var sqlAdministratorLogin = 'infraadmin'
var sqlAdministratorPassword = 'P${uniqueString(resourceGroup().id, '224F5A8B-51DB-46A3-A7C8-59B0DD584A41')}x!'


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: 'logAnalytics'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource sqlServer 'Microsoft.Sql/servers@2014-04-01' ={
  name: sqlServerName
  location: resourceGroup().location

  properties:{
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
  }

  resource sqlServerDatabase 'databases@2014-04-01' = {
    name: sqlDbName
    location: resourceGroup().location
    properties: {
      edition: 'Basic'
    }
  }

  resource sqlServerName_activeDirectory 'administrators@2021-02-01-preview' = {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      login: webModule.outputs.webApplicationName
      sid: webModule.outputs.webApplicationPrincipalId
      tenantId: webModule.outputs.webApplicationTenantId
    }
  }  

  resource sqlServerName_AllowAllWindowsAzureIps 'firewallRules@2021-02-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }  
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: webModule.outputs.webApplicationPrincipalId
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

  resource keyVaultSecret 'secrets@2019-09-01' = {
    name: 'testSecret'
    properties: {
      value: 'hello from bicep'
    }
  }  
}



resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'appServicePlan'
  kind: 'linux'

  location: resourceGroup().location
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  properties:{
    reserved: true
  }  
}

module webModule 'webapp.bicep' = {
  name: 'webAppDeploy'
  params: {
    appServicePlanId:appServicePlan.id
    keyVaultName:keyVaultName
    sqlDbName:sqlDbName
    sqlServerFQDN:sqlServer.properties.fullyQualifiedDomainName
    logAnalyticsWorkspaceId:logAnalyticsWorkspace.id
  }
}


output websiteAddress string = 'https://${webModule.outputs.webApplicationDefaultHostName}/'
