variable "resource_group_name" {
  description = "Resource group containing the staging network resources."
  type        = string
}

variable "location" {
  description = "Azure region for the staging network resources."
  type        = string
}

variable "vnet_name" {
  description = "Virtual network name."
  type        = string
}

variable "vnet_cidr" {
  description = "VNet address space."
  type        = list(string)
}

variable "cae_subnet_name" {
  description = "Subnet name for Container Apps Environment."
  type        = string
}

variable "cae_subnet_cidr" {
  description = "Subnet address prefix for Container Apps Environment."
  type        = list(string)
}
