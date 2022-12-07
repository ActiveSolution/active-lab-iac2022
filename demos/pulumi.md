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

4. Select __azure-csharp__
    - project name: `Enter`
    - project description: `Enter`
    - stack name: `Enter`
    - passphrase: Test123!
    - azure-native:location: westeurope

5. Open folder in VS Code
    - `code .`

6. Show contents of project
    - Pulumi.yaml and Pulumi.dev.yaml

7. Open __Program.cs__

8. Remove all existing resources

9. Create a new instance of `AzureNative.Resources.ResourceGroup`
    - Code: `var rg = new ResourceGroup("MyPulumiDemo");`

10. Explain location being picked up from stack configuration

11. Create a storage account resource
    - Code: `new StorageAccount("pulumidemo");`

12. Show red squiggly complaining about `args` missing

13. Add `args` parameter
        new() {}

15. Explain some `args` properties having to be set

16. Set the resource group name, kind and Sku and replication type of the account
    - `ResourceGroupName` = `rg.Name`
    - `Kind` = `Kind.StorageV2`
    - `Sku` = `new SkuArgs { Name = SkuName.Standard_LRS }`

17. Open terminal (`Ctrl + ö`)

18. Deploy infrastructure
    - pulumi up
    - Passphrase: Test123!
    - Yes

19. Open Azure Portal and show the created resources
    - Explain the weird naming

20. Disable "Secure transfer required" under Configuration and save

21. Deploy Pulumi stack again to show the change not being caught
    - pulumi up
    - No

22. Deploy Pulumi stack again with --refresh to show Pulumi picking up change
    - pulumi up --refresh
    - No

23. Tear down the infrastructure
    - pulumi destroy -y

24. Open Azure Portal and show that the resources have been removed