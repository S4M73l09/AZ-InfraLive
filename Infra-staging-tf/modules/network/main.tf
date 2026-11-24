resource "azurerm_virtual_network" "general" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_cidr
}

resource "azurerm_subnet" "cae" {
  name                 = var.cae_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.general.name
  address_prefixes     = var.cae_subnet_cidr

  delegation {
    name = "container-apps"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  #checkov:skip=CKV2_AZURE_31:Staging mantiene ACR Basic público y no configura NSG en la subnet de Container Apps.
}

resource "azurerm_private_dns_zone_virtual_network_link" "containerapps" {
  name                  = "aca-dns-link"
  private_dns_zone_id   = azurerm_private_dns_zone.containerapps.id
  virtual_network_id    = azurerm_virtual_network.general.id
}

resource "azurerm_private_dns_zone" "containerapps" {
  name                = "privatelink.azurecontainerapps.io"
  resource_group_name = var.resource_group_name
}
