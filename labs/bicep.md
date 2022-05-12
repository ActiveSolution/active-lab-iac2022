# Infrastructure as Code Labs - Bicep
Welcome to the Bicep lap for the Infrastructure as code workshop. In this lab, you will setup the following infrastructure resources in Azure using Bicep, and validate your deployed infrastructure using a prebuild web application along the way:

* Azure App Service running on Linux
* Azure Key Vault for storing sensitive information, such as passwords
* Azure SQL Server and a SQL database
* Application Insights resource backed by a Log Analytics workspace

## Prerequisites
To complete the lab you need to install the Bicep tooling which includes

* Azure CLI (or Azure Powershell)
* Visual Studio Code
* Bicep extension for Visual Studio Code

You can find the latest installation instructions for your environment here:
https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install

Verify that you have the Bicep CLI working properly by running:
```bat
az bicep version
```

With the tools in place, you need to either log in to the Azure CLI, or, if you are already logged in, validate that you are using the correct subscription.

To log in, run the following command, and go through the login procedure

```bash
> az login
```

To validate that you are using the correct subscription, you can run

```bash
> az account show
{
  ...
  "id": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  ...
  "name": "My Subscription"
}
```

If this is not the required subscription, you can list the available subscriptions by running

```bash
> az account list
```

and select the subscription you want by running

```bash
> az account set -s <SUBSCRIPTION ID>
```


## Setting up the project
Create a new folder for your bicep project and open the folder in Visual Studio Code. In the folder, create a new file called _template.bicep_. Open the file in the editor and verify that the Bicep extension in Visual Studio code is working properly. This extension will help you to develop Bicep files much more efficiently, by adding Intellisense and code snippets.

![image](https://user-images.githubusercontent.com/847244/135446853-2ed95f3c-cdb3-4283-831d-8b2aed3f45aa.png)

## Azure App Service
To run a web application on Azure App Service, you need an app service plan and an app service. In this lab, you will deploy an existing, containerized, web application that will help you validate the infrastructure as you deploy it along the way.

To create the app service plan, typ in the newly created file in visual studio *res-app-plan*, you will see a tooltip, hit ENTER and it will autofill for you. This uses one of the code snippets available in the Bicep extension for Visual Studio Code. Now we need to give the plan a name, and specify that it should be running on Linux.

![image](https://user-images.githubusercontent.com/847244/136973195-60581077-e20f-4c83-8054-059bf1a0c600.png)

Make the following changes to the resource:

* Name the app service plan 'appServicePlan'

* Change location to 'resourceGroup().location'

* Add a *kind* property and give ut the value 'linux'

* Add a *properties* section to the app service plan resource, and add a property called *reserved* with the value true.

When done, your resource should look like this:
```bicep
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'appServicePlan'
  location: resourceGroup().location
  kind: 'linux'
  sku: {
    name: 'F1'
    capacity: 1
  }
  properties:{
    reserved: true
  }
}
```

Azure App Services are deployed in the global _.azurewebsites.net_ domain and therefor we need to give it a globally unique name. To do this, we'll add a variable that will generate a unique name for us.

Add this to the top of the file.

```bicep
var webAppName = 'webapp${uniqueString(resourceGroup().id)}'
```
uniqueString will generate a deterministic hash string based on the input. This means that it will return the same output value every time, if we call it with the same input value. In this case we pass the id of the our resource group. Since that will not change over the lifetime of the resource group, we will get the same name for the app service every time. Read more about the uniqueString template functiom here: https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-functions-string#uniquestring

Now, create the app service by using the snippets again by typing *res-web-app* and hit ENTER.

* Reference the variable for the name of the app service
  ```bicep
  name: webAppName
  ```
* Change the reference to the app service plan (the *serverFarmId* property) from a string to a typed reference, using the *appServicePlan.id* property
  ```bicep
  properties: {
    serverFarmId: appServicePlan.id
  }
  ```
* Specify that the app service should use a managed identity, by adding in _identity_ section to the resource (https://docs.microsoft.com/en-us/azure/app-service/overview-managed-identity?tabs=dotnet).
  ```bicep
    identity: {
    type: 'SystemAssigned'
  }
  ```
* Specify that this should run as a Linux docker container and which image to use, by adding a new _siteConfig_ section within the properties section. In it, add a _linuxFxVersion_ property that should contain the full name of the docker image:
```bicep
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig:{
      linuxFxVersion:'DOCKER|iacworkshop.azurecr.io/infrawebapp:v1'
    }
  }
```
* Since the docker image that we use is published to a private Azure Container Registry, we need to add properties that contain the credentials. To do this, we add an *appSettings* section and add the following properties:

* DOCKER_REGISTRY_SERVER_URL - The URL of the container registry (https://iacworkshop.azurecr.io)
* DOCKER_REGISTRY_SERVER_USERNAME - Login to the registry (iacworkshop)
* DOCKER_REGISTRY_SERVER_PASSWORD - Password to the registry (Ask for this)

Your webApplication resource should now look something like this:

```bicep
resource webApplication 'Microsoft.Web/sites@2018-11-01' = {
  name: webAppName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/appServicePlan': 'Resource'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig:{
      linuxFxVersion:'DOCKER|iacworkshop.azurecr.io/infrawebapp:v1'
      appSettings:[
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
          value: 'XXXXXXXXXXXXXXXXXXXXXXXX'
        }
      ]
    }
  }
}
```

Let's deploy this template to your Azure subscription. Before we do this, we need to create a resource group that will contain our resources. To do this, we use the _az group create_ command. Replace <myResourceGroup> with a suitable name:

```bat
az group create --name <myResourceGroupName> --location westeurope
```

Then, run the following command from the directory where your Bicep template is located:

```bat
az deployment group create --resource-group <myResourceGroupName> --template-file template.bicep
```

This will generate an ARM template and then submit it to Azure Resource Manager which will provision the app service resource. The deployment should complete successfully, the command will return the deployment information in a JSON format.

To test the web application that you just deployed, you need to find out what name has been assigned to it. You can do this in the Azure portal, but working with the CLI is usually faster and more efficient.

To list all web applications in your current subscription, run
```bat
az webapp list -o table
```
Locate your web app and copy the URL shown in the *DefaultHostName* column (\*\*\*\*\*.azurewebsites.net)
  
![image](https://user-images.githubusercontent.com/847244/136797158-4767b70a-fc5d-43ea-97de-1f76656c5267.png)

Open a web browser and browse to the URL that you just copied. 

  > **Note**: It will take some time before the application loads the first time, since it needs to pull the container image.

When it loads, you should see a message that the Azure KeyVault is missing. This makes sense, since we haven't created it yet :-)  But it means that the app service is running properly, and that it has pulled the container image using the supplied credentials.


## Parameterize template
Instead of hardcoding various values in the template, we can extract them into parameters that will be passed at deploy time. This allows us to for example deploy the same template into multiple environments (dev, test, prod) with different configuration in each environment. 

To start with, we want to be able to specify which service plan (SKU) to use for our app service plan (instead of hardcoding F1 like we do now). This is likely something that will change depending on which environment that you are deploying the app service into, so it makes a lot of sens to parameterize this.

Add a new parameter at the top of the file:

```bicep
param appServicePlanSku string
```
Then change the appServicePlan sku setting to refer to the parameter instead:

```bicep
sku: {
    name: appServicePlanSku
    capacity: 1
  }
```

A convenient way to pass the parameter values to a deployment is to create a separate parameter file. This is a JSON file that contains all parameters that you want to pass with the corresponding value.

Add a new file called *template.parameters.json* to the same folder as the template.bicep file, and paste in the following code:

**template.parameters.json**
```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "appServicePlanSku": {
            "value": "F1"
        }
    }
}
```

To use this file when deploying, use the --parameters option and specify the parameters file like this:

```bat
az deployment group create --resource-group <myResourceGroupName> --template-file template.bicep --parameters "@template.parameters.json"
```
The deployment should complete successfully without making any changes.

> **Note**: The values for the parameters will in a production scenario typically be supplied from within a deployment pipeline, such as Azure Pipelines or Github Actions.

## Storing and accessing secrets with Azure Keyvault
Azure Key Vault is a managed service for storing sensitive information, such as secrets, keys and certificates. In this lab, we'll access the key vault from the web application and read a secret value from it.
  
Learn more about Azure Key Vault here:
https://docs.microsoft.com/en-us/azure/key-vault/general/basic-concepts

First, add a variable in the template.bicep file that will generate a unique name for the key vault:

```bicep
var keyVaultName = 'keyvault${uniqueString(resourceGroup().id)}'
```

* Then use the snippet again by typing in the template.bicept file *res-keyvault* and hit ENTER to create the resource for the azure keyvault.
  
* Use the variable to assign the name to the vault.
  ```bicep
  resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
    name: keyVaultName
  ```
* Remove everything except name, location, tenantId and the sku properties. Change the tenantId property to reference the tenantId property of the current subscription (which you can access through the subscription() function)
  
```bicep
tenantId: subscription().tenantId
```
  
* Add an empty accessPolicies section:
  
```bicep
accessPolicies:[]
```

In addition, we'll add a secret to the key vault. The demo application will read the secret to validate that it has access to the vault. We can do this from the Bicep template itself, by adding a secrets resource.
  
* Add the secret resource, use the snippet by typing *res-keyvault-secret* and hit ENTER.
  
* Cut and paste the new *keyVault_testSecret* resource into the *keyVault* resource.
  
* Strip the *Microsoft.Keyvault/vaults* prefix. This is not needed since the resource is now nested.
  
* Name the secret 'testSecret' and give it any value.

The key vault resource, including the secret, should now look something like this:

```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: resourceGroup().location

  properties: {
    tenantId: subscription().tenantId
    accessPolicies:[]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }

  resource keyVault_testSecret 'secrets@2021-04-01-preview' = {
    name: 'testSecret'
    properties: {
      value: 'hello from bicep'
    }
  }
}
```

To be able to fetch information from the key vault, the web app needs to know the name of the KeyVault. For this, the web application expects an app setting called __KeyVaultName__ that should contain the name of the KeyVault. Within the existing _appSettings_ section of the appService, add a new setting for the keyVaultName:

```bicep
appSettings: [
        {
          name: 'keyVaultName'
          value: keyVaultName
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://iacworkshop.azurecr.io'
        }
        ....
```

Save the file, and run the deployment command again to create the key vault.

```bat
az deployment group create --resource-group <myResourceGroupName> --template-file template.bicep --parameters "@template.parameters.json"
```

Go back to the web page (****.azurewebsites.net) and refresh the page. Unfortunately, the web application will still report the same error. This is because we haven't given the identity of the app service access to the key vault. This is done by adding an access policy.

Modify the *accessPolicies* section in the *keyVault* resource to look like this:

```bicep
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
```

This will create an access policy for the identity of the app service, and give it permissions to list and read secrets from the vault.

Redeploy the template again using the same command as before, and then refresh the web page. The error message about the keyvault is missing should now be gone.
However, it now complains that a connection string to the SQL database is missing.


## Add SQL storage
The web application uses SQL as storage, so we need to create an Azure SQL Server and an Azure SQL Database.

First, add some variables containing the (unique) name of the SQL Server, the name of the database and the credentials:

```bicep
var sqlServerName = 'sqlserver${uniqueString(resourceGroup().id)}'
var sqlDbName = 'infradb'
var sqlAdministratorLogin = 'infraadmin'
var sqlAdministratorPassword = 'P${uniqueString(resourceGroup().id, '224F5A8B-51DB-46A3-A7C8-59B0DD584A41')}x!'

```
> **Note**: Generating a password like this is not recommended, and only done for the purpose of this lab. There is an optional step at the end of this lab that shows how you can refer to secrets in a key vault from within a bicep template.

To add the two snippets for an Azure SQL Server resource and an Azure SQL database resource, type *res-sql* and hit ENTER.
  
* cut and paste the *sqlServerDatabase* resource into the *sqlServer* resource.
  
* Remove the parent property and the *Microsoft.Sql/servers/* prefix.
  
* Remove all properties for the database except edition property.
  
* In the *sqlServer* resource add a new properties object with the properties *administratorLogin* and *administratorLoginPassword*.
  
* Reference the credentials for the SQL Server to the new properties.
  
* Reference the names of both the resources (sqlServerName and sqlDbName).

```bicep
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
}
```

Now we have the web app and the database defined, but we need to make sure that the web application can talk to the database. This requires both a connection string and the necessary permissions for the identity of the web app.

We can define the connection string in the siteConfig/connectionStrings property in the *webApplication* resource, like so:

```bicep
siteConfig: {
      linuxFxVersion: 'DOCKER|iacworkshop.azurecr.io/infrawebapp:v1'

      connectionStrings: [
        {
          name: 'infradb'
          connectionString: 'Data Source=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};Authentication=Active Directory Interactive;'
          type: 'SQLAzure'
        }
      ]

```

Next up, we will set the managed identity of the app service as the active directory admin of the Azure SQL Server, using the administrators resoure within the SQL Server resource:

```bicep
  resource sqlServerName_activeDirectory 'administrators@2021-02-01-preview' = {
   name: 'ActiveDirectory'
   properties: {
     administratorType: 'ActiveDirectory'
     login: webApplication.name
     sid: webApplication.identity.principalId
     tenantId: webApplication.identity.tenantId
   }
 }
```

> **Note**: Setting the app service identity as the AAD admin for the SQL Server is obviously not a best practice, but is done here for simplicity.

Finally, to make sure that the traffic between the app service and the database is allowed through, we need to add a firewall rule to the SQL Server resource that allows all traffic coming from within Azure:

```bicep
  resource sqlServerName_AllowAllWindowsAzureIps 'firewallRules@2021-02-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
```

The whole sqlServer resource should now look like this:

```bicep
resource sqlServer 'Microsoft.Sql/servers@2014-04-01' = {
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
      login: webApplication.name
      sid: webApplication.identity.principalId
      tenantId: webApplication.identity.tenantId
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
```

Redeploy the template, and then refresh the web application. The error about the missing connection string should now be gone. But now it complains that is lacks settings for Application Insights. Man, what a grumpy application! Let's add some more resources then.
  
> **Note**: 
  If you want to see all the resources that you have created so far, you can either browse to the resource group in the Azure portal, or you can run the following command:

  ```bat
  az resource list --resource-group <myResourceGroup> -o table
  ```
  
This will list all resources within the resource group, and should show you the app service, app service plan, the Azure key vault, Azure SQL Server and the Azure SQL Database. 


## Add Application Insights
Of course we want to make sure that we are monitoring our app service, and to do that we'll add an Application Insights resource to the template. We'll use the recent version of this resource type, which supports storing all information in a Log Analytics workspace for further analysis.
  
 > For more information about Azure Application Insights and Log Analytics, see https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview

   
* Use the snippet to add a Log Analytics workspace by typing *res-log-analytics-workspace* and hit ENTER.
  
* Name it 'logAnalytics'
  
* Change the sku property value to 'PerGB2018'
```bicep
    sku: {
      name: 'PerGB2018'
    }
```
  
* Add an application insights resource with the help of the snippet by typing *res-app-insights* and hit ENTER.
  
* Name the resource 'appInsights'
  
* Add a reference to the logAnalyticsWorkspace id

```bicep
 properties: {
   Application_Type: 'web'
   WorkspaceResourceId:logAnalyticsWorkspace.id
 }
```

* To connect the appInsights resource with the app service resource, add a *tags* section to the appInsights resource that contains the id of the app service resource:

```bicep
tags: {
    'hidden-link:${webApplication.id}': 'Resource'
  }
```

Both resources should now look like this:

```bicep
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: 'logAnalytics'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
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
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}
```

The last step is to configure the app settings of the app service to include the required Application Insights keys. But there is a problem here, we already have a reference from the appInsights resource to the appService resource. This would create a cyclic reference and wont work.

Instead, we can extract the app settings into a separate resource, that depends on both the app service and the app insights resource. This resolves the cyclic dependency problem. Add the following new resource:

```bicep
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
        value: 'XXXXXXXXXXXXXXXX'
      }
    ]
  }
  dependsOn: [
    webApplication
    appInsightsComponents
  ]
}
```

  > **Note**: Remember to change XXXXXXXXXXXX to the same docker registry password tht you used before.
  
Remove all of the app settings from the appSettings section in the webApplication resource.
Redeploy the template and refresh the web page. It should now show that your entire infrastructure is configured correctly.


## Add output variable

In the beginning of this lab, you went looking for the generated name of the web app. This is not very convenient, and in many cases you also need this information later in your deployment pipeline, for example when running smoke tests against a newly deployed web application.

We can use output variables to overcome this problem, by specifying information that should be returned when running the deployment. Let's add an output variable that will contain the name of the generated web app name:

```bicep
output websiteAddress string = 'https://${webApplication.properties.defaultHostName}/'
```

Run the deployement again. When it has finished, you can access the output by using the az deployment group show command:

```bat
az deployment group show --name template --resource-group <resourceGroupName> --query properties.outputs.websiteAddress.value
```

> **Note**: The name *template* is used since we haven't given the deployment a specific name. The default name is set to the name of the bicep template file (e.g. template)


# Optional excercises

## 1. Modularize template
Up until now, we have added all resources to the same bicep file. This is fine for smaller deployments, but for larger deployments it is often beneficial to split up the deployment into multiple template files. In addition to make it easier to read and understand, it also allows for reuse of common resource across multiple deployment.

In Bicep, you can use *modules* to split up a deployment template in multiple parts. In this lab, we could for example extract the web application, webAppSettings and the application insights resource into a separate Bicep module, that will refer to resources defined in the main template file (the app service plan, SQL Server and the log analytics workspace).

* Create a new file called *webapp.bicep*

* Move webApplication, webAppSettings and appInsightsComponents resources to this file (remove them from template.bicep)

* Move the *webAppName* variable from template.bicep to webapp.bicep

To make it a usable module, the template that uses it must be able to pass in the required information as parameters, and then reference the output of this module. So we need to add parameters for the information that the app service and app insights resource needs, and then we will return the generated app service as an output property. Add the following parameters at the top of the webapp.bicep file:

```bicep
param appServicePlanId string
param keyVaultName string
param sqlServerFQDN string
param sqlDbName string
param logAnalyticsWorkspaceId string
```

Now change all of the resources variables to the new parameters, so for example *sqlServer.properties.fullyQualifiedDomainName* in the connectionstring becomes *sqlServerFQDN* and so on.

```bicep
connectionStrings: [
        {
          name: 'infradb'
          connectionString: 'Data Source=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};Authentication=Active Directory Interactive;'
          type: 'SQLAzure'
        }
```

to

```bicep
connectionStrings: [
        {
          name: 'infradb'
          connectionString: 'Data Source=tcp:${sqlServerFQDN},1433;Initial Catalog=${sqlDbName};Authentication=Active Directory Interactive;'
          type: 'SQLAzure'
        }
```

Then add the following output properties at the end of the file:

```bicep
output webApplicationName string = webApplication.name
output webApplicationPrincipalId string = webApplication.identity.principalId
output webApplicationTenantId string = webApplication.identity.tenantId
output webApplicationDefaultHostName string = webApplication.properties.defaultHostName
```
  
 To use the module, we'll import it using the *module* keyword that references the file to import, and passing the necessary parameters. Add it at the end of the *template.bicep* file, right before the output variable:

```bicep
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
```

Now, what's left to do is to modify all references to the webApplication and appInsightsComponents resource using the output variables from the module instead.

So, for example, change:

```bicep
  resource sqlServerName_activeDirectory 'administrators@2021-02-01-preview' = {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      login: webApp.name
      sid: webApp.identity.principalId
      tenantId: webApp.identity.tenantId
    }
  }
```

to

```bicep
 resource sqlServerName_activeDirectory 'administrators@2021-02-01-preview' = {
    name: 'ActiveDirectory'
    properties: {
      administratorType: 'ActiveDirectory'
      login: webModule.outputs.webApplication.name
      sid: webModule.outputs.webApplication.identity.principalId
      tenantId: webModule.outputs.webApplication.identity.tenantId
    }
  }
}
```

As you can see, we can still reference the various properties of the webapp resource, but we need to do it by using the output variable from the webapp module.

When you have updated all places, you can run the deployment again to verify that it works as expected. The end result will be exactly the same, but now you have a more manageable structure that will scale better as the size and complexity of your infrastructure grows.


## 2. Reference senstive information in Azure KeyVault
Instead of generating passwords like we did before, a better way is to keep this information in Azure Key Vault and then refer to these secrets directly from the ARM template. This allows us to keep these secrets secure without storing them anywhere else but in the key vault during deployment.

In our case, we could retreive the SQL Server credentials from a key vault instead.

To add the SQL secrets to the key vault, we must first give ourself access to the vault. 

First, retrieve the object ID for your user, by running:

```bat
az ad user show --id <youremail>
```

Grab the KeyVault name and the id:

```bat
az keyvault list
```

**TIP**: Save the KeyVault id, you will need it further down in the lab. 

Grab the objectId and KeyVault name from the outputs and use it in the next command:

```bat
az keyvault set-policy --name <keyVaultName> --object-id <yourUserObjectId> --secret-permissions get list set
```

Now, you can add the following secrets:

```bat
az keyvault secret set --vault-name <keyVaultName> --name sqlAdminLogin --value infraadmin
az keyvault secret set --vault-name <keyVaultName> --name sqlAdminPassword --value <yourSecurePassword>
```

  >**NOTE**: You need to set a complex password or the deployment will fail later in the lab.

To use these values, we can now reference the secrets directly from the parameters file.

* Remove the variables that you added before, *sqlAdministratorLogin* and *sqlAdministratorPassword*

* Add the following parameters to your bicep file:

```bicep
param sqlAdministratorLogin string
@secure()
param sqlAdministratorPassword string
```

* Then add the following parameters to your template.parameters.json file, replacing \<subscriptionId\>, \<resourceGroupName\> and \<keyVaultName\> with your values:

```bicep
  "sqlAdministratorLogin": {
     "reference": {
         "keyVault": {
             "id": "/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>/providers/Microsoft.KeyVault/vaults/<keyVaultName>"
         },
         "secretName": "sqlAdminLogin"
     }
 },
 "sqlAdministratorPassword": {
     "reference": {
         "keyVault": {
             "id": "/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>/providers/Microsoft.KeyVault/vaults/<keyVaultName>"
         },
         "secretName": "sqlAdminPassword"
     }
 }
```

> **TIP**: If you didn't copy the KeyVault id earlier in the lab then grab the subscription id by running:

```bat
az account show --query id
```

Or the whole KeyVault id by running:

```bat
az keyvault list
```

When running the deployment, it will now dynamically fetch the secrets from the key vault and populate the parameter values for the SQL admin credentials.

Run the deployment. You will get an error, stating that the secrets can't be retrieved. The reason for this is that the Azure Resource Manager (ARM) service doesn't have permission by default to read from our keyvault. This can easily be enabled by adding a single property to the keyvault resource, *enabledForTemplateDeployment*:

```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    tenantId: subscription().tenantId
    enabledForTemplateDeployment:true
 ...
```

Redeploy the template. You will still get the same error and the reason for this is that the parameters that references the keyvault are evaluated before the new property is assigned to the existing keyvault resource. To get around this, we could remove the parameters temporarily, deploy the template, and then add them back. We could also delete the keyvault and let the deployment recreate it. For simplicity, we will we just set the keyvault property manually instead, and then redeploy.

Run the following command to update your keyvault to allow the ARM service to reference it during deployments:

```bat
az keyvault update --name <keyVaultName> --enabled-for-template-deployment true
```

Now, deploy the template once more and verify that the deployment still works as expected.

