terraform {
  required_version = "= 1.14.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.57.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.12.0, < 2.0.0"
    }
  }
}
