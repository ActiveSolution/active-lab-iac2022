resource "azurerm_linux_web_app" "app" {
  name                = var.web_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = var.app_service_plan_id

  site_config {
    application_stack {
      docker_image     = "iacworkshop.azurecr.io/infrawebapp"
      docker_image_tag = "v1"
    }
    always_on         = startswith(lower(var.app_service_plan_sku), "f") ? false : true
    use_32_bit_worker = startswith(lower(var.app_service_plan_sku), "f") ? true : false
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL                 = "https://iacworkshop.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME            = "iacworkshop"
    DOCKER_REGISTRY_SERVER_PASSWORD            = "XXXXXXXXXXXX"
    KeyVaultName                               = var.key_vault_name
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.ai.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.ai.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
    XDT_MicrosoftApplicationInsights_Mode      = "recommended"
  }

  connection_string {
    name  = var.db_name
    type  = "SQLAzure"
    value = "Data Source=tcp:${var.sql_server_domain_name}.database.windows.net,1433;Initial Catalog=infradb;Authentication=Active Directory Interactive;"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_application_insights" "ai" {
  name                = var.ai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
}

output "web_app_name" {
  value = azurerm_linux_web_app.app.name
}

output "web_app_identity" {
  value = azurerm_linux_web_app.app.identity[0]
}

output "website_address" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}/"
}
