terraform {
  backend "azurerm" {
    resource_group_name  = "rg-infralive-state"
    storage_account_name = "stinfralivest01"
    container_name       = "tfstate-staging"
    key                  = "infra-staging.tfstate"
    use_azuread_auth     = true
    use_cli              = true
  }
}
