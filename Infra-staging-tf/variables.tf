variable "resource_group_name" {
  description = "Resource group for staging infrastructure."
  type        = string
}

variable "location" {
  description = "Azure region for staging."
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

variable "pe_subnet_name" {
  description = "Subnet name for Private Endpoints."
  type        = string
}

variable "pe_subnet_cidr" {
  description = "Subnet address prefix for Private Endpoints."
  type        = list(string)
}

variable "log_analytics_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "containerapps_env_name" {
  description = "Container Apps environment name."
  type        = string
}

variable "containerapp_name" {
  description = "Container App name."
  type        = string
}

variable "monitor_workspace_name" {
  description = "Azure Monitor workspace name (Managed Prometheus)."
  type        = string
}

variable "grafana_name" {
  description = "Azure Managed Grafana name."
  type        = string
}

variable "acr_name" {
  description = "Azure Container Registry name (global, lowercase, alphanumeric)."
  type        = string
}

variable "acr_sku" {
  description = "ACR SKU (Basic/Standard/Premium)."
  type        = string
}

variable "image_name" {
  description = "Container image name in ACR."
  type        = string
}

variable "image_tag" {
  description = "Container image tag."
  type        = string
}

variable "repo_url" {
  description = "Git repository URL used as build context for ACR Task."
  type        = string
}

variable "repo_branch" {
  description = "Git branch used by ACR Task."
  type        = string
}

variable "enable_acr_task" {
  description = "Enable ACR Task creation (typically true in CI, false in local plan)."
  type        = bool
  default     = false
}

variable "repo_token" {
  description = "Token used by ACR Task to access repository context."
  type        = string
  sensitive   = true
  default     = ""
}
