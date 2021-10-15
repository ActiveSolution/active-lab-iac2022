terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.project_name
  location = "westeurope"
}

resource "azurerm_app_service_plan" "plan" {
  name                = "${local.project_name}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "linux"
  reserved            = true

  sku {
    tier = var.app_service_plan_tier
    size = var.app_service_plan_sku
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  suffix       = lower(random_string.suffix.id)
  project_name = lower(var.project_name)
}

resource "azurerm_app_service" "app" {
  name                = "${local.project_name}-web-${local.suffix}"
  location            = azurerm_app_service_plan.plan.location
  resource_group_name = azurerm_app_service_plan.plan.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.plan.id

  site_config {
    linux_fx_version          = "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1"
    always_on                 = lower(var.app_service_plan_tier) == "free" ? false : true
    use_32_bit_worker_process = lower(var.app_service_plan_tier) == "free" ? true : false
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL                 = "https://iacworkshop.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME            = "iacworkshop",
    DOCKER_REGISTRY_SERVER_PASSWORD            = "XXX"
    KeyVaultName                               = "${local.project_name}-kv-${local.suffix}"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.ai.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.ai.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
    XDT_MicrosoftApplicationInsights_Mode      = "recommended"
  }

  identity {
    type = "SystemAssigned"
  }

  connection_string {
    name  = "infradb"
    type  = "SQLAzure"
    value = "Data Source=tcp:${local.project_name}-sql-${local.suffix}.database.windows.net,1433;Initial Catalog=infradb;Authentication=Active Directory Interactive;"
  }
}

resource "azurerm_key_vault" "kv" {
  name                = "${local.project_name}-kv-${local.suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  access_policy {
    tenant_id = azurerm_app_service.app.identity[0].tenant_id
    object_id = azurerm_app_service.app.identity[0].principal_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

resource "azurerm_key_vault_secret" "secret" {
  name         = "testSecret"
  value        = "secretValue"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "random_password" "sql_admin_password" {
  length  = 16
  special = true
}

resource "azurerm_mssql_server" "sql_server" {
  name                         = "${local.project_name}-sql-${local.suffix}"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  version                      = "12.0"
  administrator_login          = "infraadmin"
  administrator_login_password = random_password.sql_admin_password.result

  azuread_administrator {
    login_username = azurerm_app_service.app.name
    object_id      = azurerm_app_service.app.identity[0].principal_id
  }
}

resource "azurerm_mssql_database" "db" {
  name        = "infradb"
  server_id   = azurerm_mssql_server.sql_server.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name    = "Basic"
  max_size_gb = 1
}

resource "azurerm_mssql_firewall_rule" "allow_azure_ips" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_log_analytics_workspace" "laws" {
  name                = "${local.project_name}-laws-${local.suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_application_insights" "ai" {
  name                = "${local.project_name}-ai-${local.suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.laws.id
  application_type    = "web"
}

output "website_address" {
  value = "https://${azurerm_app_service.app.default_site_hostname}/"
}