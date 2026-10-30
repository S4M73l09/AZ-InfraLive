data "azurerm_resource_group" "staging" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "staging" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.staging.name
  address_space       = var.vnet_cidr
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = var.pe_subnet_name
  resource_group_name               = data.azurerm_resource_group.staging.name
  virtual_network_name              = azurerm_virtual_network.staging.name
  address_prefixes                  = var.pe_subnet_cidr
  private_endpoint_network_policies = "Disabled"
}


resource "azurerm_subnet" "cae" {
  name                 = var.cae_subnet_name
  resource_group_name  = data.azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = var.cae_subnet_cidr
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.staging.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-dns-link"
  resource_group_name   = data.azurerm_resource_group.staging.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.staging.id
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.staging.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.staging.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "containerapps" {
  name                  = "aca-dns-link"
  resource_group_name   = data.azurerm_resource_group.staging.name
  private_dns_zone_name = azurerm_private_dns_zone.containerapps.name
  virtual_network_id    = azurerm_virtual_network.staging.id
}

resource "azurerm_private_dns_zone" "containerapps" {
  name                = "privatelink.azurecontainerapps.io"
  resource_group_name = data.azurerm_resource_group.staging.name
}

resource "azurerm_private_dns_a_record" "containerapps_env" {
  name                = "${var.containerapps_env_name}.${var.location}"
  zone_name           = azurerm_private_dns_zone.containerapps.name
  resource_group_name = data.azurerm_resource_group.staging.name
  ttl                 = 300
  records             = [azurerm_container_app_environment.staging.static_ip_address]
}

resource "azurerm_log_analytics_workspace" "staging" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.staging.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "staging" {
  name                           = var.containerapps_env_name
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.staging.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.staging.id
  infrastructure_subnet_id       = azurerm_subnet.cae.id
  internal_load_balancer_enabled = true
}

# Container App privada de staging; consume imagen desde ACR via identidad administrada.
resource "azurerm_container_app" "nginx" {
  name                         = var.containerapp_name
  resource_group_name          = data.azurerm_resource_group.staging.name
  container_app_environment_id = azurerm_container_app_environment.staging.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.staging.login_server
    identity = "SystemAssigned"
  }

  ingress {
    external_enabled = false
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "nginx"
      image  = "${azurerm_container_registry.staging.login_server}/${var.image_name}:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"
    }

  }
}

# Escalado HTTP/KEDA aplicado con AzAPI para cubrir capacidades no expuestas totalmente en azurerm.
resource "azapi_update_resource" "nginx_scale" {
  type        = "Microsoft.App/containerApps@2023-05-01"
  resource_id = azurerm_container_app.nginx.id

  body = jsonencode({
    properties = {
      template = {
        scale = {
          rules = [
            {
              name = "http"
              http = {
                metadata = {
                  concurrentRequests = "20"
                }
              }
            }
          ]
        }
      }
    }
  })

  depends_on = [azurerm_container_app.nginx]
}

# ACR privado para almacenar imagenes de staging usadas por la Container App.
resource "azurerm_container_registry" "staging" {
  name                          = var.acr_name
  resource_group_name           = data.azurerm_resource_group.staging.name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = false
}

# Permite a la identidad de la Container App descargar imagenes desde ACR.
resource "azurerm_role_assignment" "acr_pull_containerapp" {
  scope                = azurerm_container_registry.staging.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.nginx.identity[0].principal_id
}

# resource "azurerm_monitor_workspace" "staging" {
#  name                = var.monitor_workspace_name
#  location            = var.location
#  resource_group_name = data.azurerm_resource_group.staging.name
#}

# resource "azurerm_dashboard_grafana" "staging" {
#  name                  = var.grafana_name
#  resource_group_name   = data.azurerm_resource_group.staging.name
#  location              = var.location
#  api_key_enabled       = true
#  grafana_major_version = 11
#}

resource "azurerm_container_registry_task" "nginx_build" {
  count                 = var.enable_acr_task ? 1 : 0
  name                  = "acr-task-nginx-staging"
  container_registry_id = azurerm_container_registry.staging.id

  lifecycle {
    precondition {
      condition     = length(trimspace(var.repo_token)) > 0
      error_message = "repo_token is required when enable_acr_task=true."
    }
  }

  platform {
    os           = "Linux"
    architecture = "amd64"
  }

  identity {
    type = "SystemAssigned"
  }

  docker_step {
    dockerfile_path      = "app/Dockerfile"
    context_path         = "${var.repo_url}#refs/heads/${var.repo_branch}"
    context_access_token = var.repo_token
    image_names          = [
      "${azurerm_container_registry.staging.login_server}/${var.image_name}:${var.image_tag}"
    ]
  }
}

# Outputs de Terraform

output "nginx_fqdn" {
  description = "Container App FQDN interno (ingress privado)."
  value       = azurerm_container_app.nginx.ingress[0].fqdn
}

# output "grafana_endpoint" {
#  description = "Azure Managed Grafana endpoint."
#  value       = azurerm_dashboard_grafana.staging.endpoint
#}

output "containerapps_env_subnet_id" {
  description = "Subnet ID used by Container Apps Environment."
  value       = azurerm_subnet.cae.id
}

output "containerapps_env_internal_lb" {
  description = "Container Apps Environment internal LB enabled."
  value       = azurerm_container_app_environment.staging.internal_load_balancer_enabled
}

output "acr_login_server" {
  description = "ACR login server."
  value       = azurerm_container_registry.staging.login_server
}
