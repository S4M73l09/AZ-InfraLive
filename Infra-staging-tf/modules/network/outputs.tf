output "cae_subnet_id" {
  value = azurerm_subnet.cae.id
}

output "containerapps_dns_zone_name" {
  value = azurerm_private_dns_zone.containerapps.name
}

output "containerapps_dns_zone_id" {
  value = azurerm_private_dns_zone.containerapps.id
}