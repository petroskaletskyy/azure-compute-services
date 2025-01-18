# Define the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate a random index to create a globally unique name
resource "random_id" "randomId" {
  byte_length = 8
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "WebApp-RG-${random_id.randomId.hex}"
  location = "North Europe"
}

# Create an App Service Plan
resource "azurerm_service_plan" "web_srv_plan" {
  name                = "WebApp-ASP-${random_id.randomId.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B2"
}

# Create a Web App
resource "azurerm_linux_web_app" "webapp" {
  name                = "cap-js-webapp-${random_id.randomId.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.web_srv_plan.id

  site_config {
    always_on = "false"
    application_stack {
      node_version = "16-lts"
    }
  }
}

resource "azurerm_app_service_source_control" "source-control" {
  app_id                 = azurerm_linux_web_app.webapp.id
  repo_url               = "https://github.com/Azure-Samples/nodejs-docs-hello-world"
  branch                 = "main"
  use_manual_integration = "true"
}

# Output the Web App URL    
output "app_service_url" {
  value = "https://${azurerm_linux_web_app.webapp.default_hostname}"
}