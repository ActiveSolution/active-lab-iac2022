# Terraform Demo

This is the "documentation" for the Terraform demo performed during the IaC workshop presentation

## Pre-reqs

* Make sure Azure CLI and Terraform CLI is installed
* Make sure the Azure CLI is pointing at the correct subscription
* Open Azure Portal in browser, and choose the correct tenant
* Make sure that the snippets file `terraform_demo.code-snippets` has been added to VS Code
  * Location: C:\Users\<USERNAME>\AppData\Roaming\Code\User\snippets

## Steps

1. Create a folder to contain the project
    - `mkdir TerraformDemo`

2. Enter folder
    - `cd TerraformDemo`

3. Open folder in VS Code
    - `code .`

4. Create a new file called __main.tf__

5. Add a Terraform configuration block
    - Snippet: tf_az_config

6. Initialize Terraform
    - `terraform init`

7. Add a new resource group resource
    - `resource "azurerm_resource_group" "rg" { }`

8. Set the name and location of the resource group
    - `name = "MyTerraformDemo"`
    - `location = "WestEurope"`

9. Add a storage account resource
    - `resource "resource "azurerm_storage_account" "my" { }"`

10. Set the name, resource group name, location, tier and replication type of the account
    - `name = "tfdemostorage123"`
    - `resource_group_name = azurerm_resource_group.rg.name`
    - `location = azurerm_resource_group.rg.location`
    - `account_tier = "Standard"`
    - `account_replication_type = "LRS"`

11. Format the document by pressing `Shift + Alt + f`
    - Warning: This can decide to remove a `{` from the `terraform` block

12. Open terminal (`Ctrl + ö`)

13. Verify the plan
    - terraform plan

14. Apply the infrastructure
    - terraform apply
    - yes + `Enter`

15. Open Azure Portal and show the created resources

16. Disable "Secure transfer required" under Configuration and save

17. Apply Terraform again to show the change being reverted
    - terraform apply
    - no + `Enter`

18. Tear down the infrastructure
    - terraform destroy
    - yes + `Enter`

19. Open Azure Portal and show that the resources have been removed