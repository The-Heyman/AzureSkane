resource "azurerm_storage_account" "sa" {
  name                     = "fnxsa${var.suffix2}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = "app-service-plan-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Y1"
  os_type             = "Linux"
}

resource "azurerm_linux_function_app" "azfxn" {
  name                = "function-app-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  storage_account_name          = azurerm_storage_account.sa.name
  storage_uses_managed_identity = true
  service_plan_id               = azurerm_service_plan.app_service_plan.id
  identity {
    type = "SystemAssigned"
  }
  https_only = true

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
    AzureWebJobsStorage                     = azurerm_storage_account.sa.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME                = "python"
  }

  site_config {
    application_stack {
      python_version = 3.11
    }

  }
  depends_on = [azurerm_service_plan.app_service_plan, azurerm_storage_account.sa]
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-analytics-workspace-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
}

resource "azurerm_application_insights" "app_insights" {
  name                = "app-insights-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  depends_on          = [azurerm_log_analytics_workspace.law]

}

# Assign the Managed Identity ownership over the app registration
resource "null_resource" "add_owner" {
  depends_on = [azurerm_linux_function_app.azfxn]

  provisioner "local-exec" {
    command = "az ad app owner add --id ${var.application_registration_object_id} --owner-object-id ${azurerm_linux_function_app.azfxn.identity[0].principal_id}"
  }
}

# Assign the Managed Identity the Application.ReadWrite.OwnedBy permission on the Graph API so it can update the client secrets on any app registration it owns
resource "null_resource" "add_app_role_assignment" {
  depends_on = [azurerm_linux_function_app.azfxn]

  provisioner "local-exec" {
    command     = "bash app-role-assignment.sh ${azurerm_linux_function_app.azfxn.identity[0].principal_id}"
    working_dir = "./scripts"
  }
}


resource "null_resource" "deploy_function_app" {
  depends_on = [azurerm_linux_function_app.azfxn]

  provisioner "local-exec" {
    command     = "bash deploy-function.sh ${azurerm_linux_function_app.azfxn.name}"
    working_dir = "./scripts"
  }
}
 
