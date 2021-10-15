variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "app_service_plan_tier" {
  type        = string
  description = "App Service Plan Tier"
  default     = "Free"
}

variable "app_service_plan_sku" {
  type        = string
  description = "App Service Plan SKU"
  default     = "F1"
}