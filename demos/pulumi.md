# Pulumi Demo

This is the "documentation" for the Pulumi demo performed during the IaC workshop presentation

## Pre-reqs

* Make sure Azure CLI, Terraform CLI, NodeJS and Pulumi is installed
* Make sure latest version of Pulumi is installed to get away from continuous messages about this
    - choco upgrade pulumi
* Make sure the Azure CLI is pointing at the correct subscription
* Open Azure Portal in browser, and choose the correct tenant

## Steps

1. Create a folder to contain the project
    - `mkdir PulumiDemo`

2. Enter folder
    - `cd TerraformDemo`

3. Show available Pulumi project types
    - pulumi new

4. Select __azure-typescript__
    - project name: `Enter`
    - project description: `Enter`
    - stack name: `Enter`
    - passphrase: Test123!
    - azure-native:location: westeurope

5. Open folder in VS Code
    - `code .`

6. Show contents of project
    - package.json
    - Pulumi.yaml and Pulumi.dev.yaml

7. Open __index.ts__

8. Remove everything but the imports

9. Update imports, removing storage and changing `resources` to azure
    - Code: `import * as azure from "@pulumi/azure-native";`

10. Create a new instance of `azure.resources.ResourceGroup`
    - Code: `const rg = new azure.resources.ResourceGroup("MyPulumiDemo");`

11. Explain location being picked up from stack configuration

12. Create a storage account resource
    - Code: `new azure.storage.StorageAccount("pulumidemo");`

13. Show red squiggly complaining about `args` missing

14. Add `args` parameter

15. Show red squiggly complaining about `args` missing `kind`, `resourceGroupName`, `sku`

16. Set the name, resource group name, king and sku and replication type of the account
    - `resourceGroupName: rg.name,`
    - `kind: azure.storage.Kind.StorageV2,`
    - `account_tier = "Standard"`
    - `sku: { name: azure.storage.SkuName.Standard_LRS }`

17. Open terminal (`Ctrl + ö`)

18. Deploy infrastructure
    - pulumi up
    - Passphrase: Test123!
    - Yes

19. Open Azure Portal and show the created resources
    - Explain the weird naming

20. Change Replication to GRS under Configuration

21. Deploy Pulumi stack again 
    - Explain error

22. Set PULUMI_CONFIG_PASSPHRASE environment variable
    - `$env:PULUMI_CONFIG_PASSPHRASE="Test123!"`

23. Deploy Pulumi stack again to show the change not being caught
    - pulumi up
    - No

24. Tear down the infrastructure
    - pulumi destroy -y

19. Open Azure Portal and show that the resources have been removed