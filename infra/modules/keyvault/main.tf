data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvault" {
  name                        = "keyvault${var.suffix2}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name                  = "standard"
  enable_rbac_authorization = true

}

resource "azurerm_eventgrid_system_topic" "system-topic" {
  name                   = "event-grid-system-topic-${var.suffix}"
  location               = azurerm_key_vault.keyvault.location
  resource_group_name    = azurerm_key_vault.keyvault.resource_group_name
  source_arm_resource_id = azurerm_key_vault.keyvault.id
  topic_type             = "Microsoft.KeyVault.vaults"
}

resource "azurerm_eventgrid_system_topic_event_subscription" "event-subscription" {
  name                  = "event-subscription-${var.suffix}"
  system_topic          = azurerm_eventgrid_system_topic.system-topic.name
  resource_group_name   = azurerm_eventgrid_system_topic.system-topic.resource_group_name
  event_delivery_schema = "CloudEventSchemaV1_0"

  azure_function_endpoint {
    function_id = var.function_id

  }

  included_event_types = ["Microsoft.KeyVault.SecretNearExpiry"]
  retry_policy {
    max_delivery_attempts = 3
    event_time_to_live    = 1440
  }
}
