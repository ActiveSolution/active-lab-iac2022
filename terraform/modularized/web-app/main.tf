resource "azurerm_app_service" "app" {
  name                = var.web_name
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = var.app_service_plan_id

  site_config {
    linux_fx_version          = "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1"
    always_on                 = lower(var.app_service_plan_tier) == "free" ? false : true
    use_32_bit_worker_process = lower(var.app_service_plan_tier) == "free" ? true : false
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL                 = "https://iacworkshop.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERNAME            = "iacworkshop",
    DOCKER_REGISTRY_SERVER_PASSWORD            = "XXX"
    KeyVaultName                               = var.key_vault_name
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
    value = "Data Source=tcp:${var.sql_server_domain_name}.database.windows.net,1433;Initial Catalog={var.db_name};Authentication=Active Directory Interactive;"
  }
}

resource "azurerm_application_insights" "ai" {
  name                = var.ai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
}

output "website_address" {
  value = "https://${azurerm_app_service.app.default_site_hostname}/"
}

output "web_app_name" {
  value = azurerm_app_service.app.name
}

output "web_app_identity" {
  value = azurerm_app_service.app.identity[0]
}