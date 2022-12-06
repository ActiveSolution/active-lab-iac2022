# Bicep Demo

This is the "documentation" for the Bicep demo performed during the IaC workshop presentation

## Pre-reqs

* Make sure Azure CLI, VS Code and the VS Code Bicep extension is installed
* Make sure the Azure CLI is pointing at the correct subscription

## Steps

1. Create a folder to contain the project
    > `mkdir bicepdemo`

2. Open folder in VS Code    

3. Create a new file called `main.bicep` and open it
    
4. Show Bicep extension is activated

5. Create a storage account manually, but don't fill out all the properties
   - Show IntelliSense
   - Show required properties completion

6. Delete, and create a storage account resource using snippet `res-storage` 
   - Give a unique name
   - Set location to `westeurope`
   - Show IntelliSense on individual properties, such as `kind`

8. Create a resource group 
   > `az group create -n bicepdemo -l westeurope`
9. Run a whatif deployment
    > az deployment group what-if -g bicepdemo -f .\main.bicep
10. Run the deployment:
    > az deployment group create -g bicepdemo -f .\main.bicep
11. Show deployment list
    > az deployment group list -g bicepdemo -o table
12. Show deployment details
    > az deployment group show -n storage -g bicepdemo
13. Show deployment in Azure portal

7. Add a parameter for the location parameter
    > `param string location`

14. Create a parameter + variable for generating the storage account name
    ``` 
    param storageAccountPrefix string

    var storageAccountName = '${storagePrefix}${uniqueString(resourceGroup().id)}'
    ```
15. Deploy again with the new parameter
    >  az deployment group create -g bicepdemo -f .\main.bicep -p location=westeurope storageAccountPrefix=jakob
    
16. Validate parameter by adding min/max
    > @minLength(3)  
    > @maxLength(11)  
    > param storageAccountPrefix string

17. Add output parameter for the generated storage account name:
    > output storageAccountName string = storageaccount.name
18. Rerun the deployment and show the output
19. Add child resources to the storage account, to create a bloc container named images:
    ```
    resource blobServices 'blobServices@2022-05-01' = {  
        name: 'default'  
        resource blobContainer 'containers@2022-05-01' = {  
            name: 'images'
        }  
    }
    ``` 
20. Rerun the deployment and show the new blob container in the Azure portal

## Modules
1. Add a new file called `storage.bicep`
2. Copy evertyhing from main.bicep to the new file
3. In main.bicep, keep the parameters only
4. Add a module deployment:
    ```
    module storage 'storage.bicep' = {
        name: 'storageDeployment'
        params: {
            location: location
            storageAccountPrefix: storageAccountPrefix
        }
    }
   ```

5. Deploy the file with the az deployment sub command:
> az deployment sub create  -f .\main.bicep -l westeurope -p location=westeurope storageAccountPrefix=jakob

## Target scopes

Change the deployment to be subscription scoped
1. Set targetScope to subscription at the top of the file:
   > targetScope = 'subscription'
2. Add the resource group deployment:
    ```
    resource bicepDemoRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
        name: 'bicepdemo'
        location: location
    }
    ```
3. Set the targetScope of the subscription module deployment to resourcegroup:
    > scope: bicepDemoRG