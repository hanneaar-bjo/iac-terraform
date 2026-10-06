# =============================================================================
#  backend-bootstrap/outputs.tf
# -----------------------------------------------------------------------------
#  Storage account-navnet er ikke kjent før stacken har kjørt – den tilfeldige
#  halen bestemmes underveis. Derfor MÅ verdien leses ut herfra; den kan ikke
#  skrives inn i backend.hcl på forhånd.
# =============================================================================

output "backend_resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Ressursgruppa state-lagringen ligger i."
}

output "backend_storage_account_name" {
  value       = azurerm_storage_account.sa.name
  description = "Storage account-et state-filene lagres i."
}

output "backend_container_name" {
  value       = azurerm_storage_container.tfstate.name
  description = "Containeren state-filene lagres i."
}

# Den nyttige: hele innholdet i shared/backend.hcl, ferdig formatert.
#
#   terraform output -raw backend_hcl_template > ../shared/backend.hcl
#
# Merk at `key` IKKE står her. Den er ulik for hver stack-instans, og sendes
# derfor som et eget -backend-config-flagg ved init.
output "backend_hcl_template" {
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    storage_account_name = "${azurerm_storage_account.sa.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    use_azuread_auth     = true
  EOT
  description = "Lim rett inn i shared/backend.hcl."
}
