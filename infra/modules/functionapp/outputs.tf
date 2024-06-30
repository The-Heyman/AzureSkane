output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id

}

output "function_managed_identity" {
  value = azurerm_linux_function_app.azfxn.identity[0].principal_id

}

output "function_app_name" {
  value = azurerm_linux_function_app.azfxn.name
}

output "resource_group_name" {
  value = azurerm_linux_function_app.azfxn.resource_group_name

}
