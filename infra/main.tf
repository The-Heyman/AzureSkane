terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.109.0"
    }
  }
}

provider "azurerm" {
  features {
  }
  skip_provider_registration = true
  subscription_id            = var.subscription_id
  tenant_id                  = var.tenant_id

}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "random_id" "suffix" {
  byte_length = 6
}

module "functionapp" {
  source                             = "./modules/functionapp"
  location                           = azurerm_resource_group.rg.location
  resource_group_name                = azurerm_resource_group.rg.name
  retention_in_days                  = 30
  suffix                             = "${random_id.suffix.hex}-${var.environment}"
  suffix2                            = "${random_id.suffix.hex}${var.environment}"
  application_registration_object_id = var.application_registration_object_id
}

module "keyvault" {
  source              = "./modules/keyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = module.functionapp.resource_group_name # create an implicit dependency between the keyvault and functionapp
  suffix              = "${random_id.suffix.hex}-${var.environment}"
  suffix2             = "${random_id.suffix.hex}${var.environment}"
  function_id         = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Web/sites/${module.functionapp.function_app_name}/functions/${var.azure_function_name}"
}


resource "azurerm_role_assignment" "key_vault_officer" {
  scope                = module.keyvault.keyvault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = module.functionapp.function_managed_identity

}
