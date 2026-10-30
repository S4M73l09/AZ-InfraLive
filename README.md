# AZ-InfraLive

Infraestructura en Azure con entornos separados, automatización CI/CD, autenticacion OIDC.

## Arquitectura actual

La infraestructura se separa en dos repositorios:

- `Azure-Bootstrap`
   - Gestiona recursos persistentes y críticos.
   - Es propietario del backend remoto de Terraform de InfraLive.
   - Gestiona el Storage Account, el contenedor y el state remoto.

- `Az-InfraLive`
   - Contiene la infraestructura de los entornos.
   - `staging` se utiliza únicamente para validación y planificación.
   - `main` será la rama autorizada para aplicar infraestructura real, incluyendo AKS.

### Backend remoto de InfraLive

El state de staging utiliza:


- Resource Group: `rg-infralive-state`
- Storage Account: `stinfralivest01`
- Container: `tfstate-staging`
- State: `infra-staging.tfstate`

El backend está definido en:


```text
Infra-staging-tf/backend.tf
```

Configuración actual:

```hcl
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
```

El backend es administrado por `Azure-Bootstrap/60-infralive-state`.

### Terraform staging

Directorio:
```bash
Infra-staging-tf/
```

Archivos principales:

`versions.tf`: versiones de Terraform y providers.
`providers.tf`: configuración de providers.
`backend.tf`: backend remoto.
`variables.tf`: variables.
`terraform.tfvars`: valores del entorno.
`main.tf`: recursos de infraestructura.

Terraform utiliza:

```bash
Terraform: 1.14.3
azurerm: 4.57.0
azapi: >= 1.12.0, < 2.0.0
```

### Politica de staging

La rama `staging` no aplica infraestructura.

Su objetivo es validar:

* Formato Terraform.
* Inicialización del backend.
* TFLint.
* Escaneo IaC con Trivy.
* Validación Terraform.
* Plan Terraform.
* Cambios destructivos o reemplazos.
* Coste estimado mediante Infracost, si está configurado.

El workflow de staging no ejecuta:

```text
terraform apply
terraform destroy
```

Los cambios se revisan mediante GitHub Actions y el plan generado.

### Autenticación Azure

GitHub Actions utiliza OIDC mediante `azure/login`:

```yaml
- name: Login to Azure using OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ vars.AZ_APPID_STAGING }}
    tenant-id: ${{ vars.AZ_TENANTID }}
    subscription-id: ${{ vars.AZ_SUBSCRIPTION_ID }}
```

El provider de Terraform necesita conocer explicitamente la suscripción:

```yaml
env:
  ARM_SUBSCRIPTION_ID: ${{ vars.AZ_SUBSCRIPTION_ID }}
```

OIDC proporciona la autenticación federada. `ARM_SUBSCRIPTION_ID` indica a Terraform la suscripción donde debe consultar los recursos.

## Workflows

### Validación de staging

Archivo:
```text
.github/workflows/staging.yml
```

Ejecuta:

```text
Checkout
Azure OIDC login
Terraform fmt
Terraform init
TFLint
Trivy
Terraform validate
Terraform plan
Guardrails contra delete/replace
Upload del plan
Infracost opcional
```

### Validación de Pull Requests

Archivo:

```text
.github/workflows/pr-staging.yml
```

Valida cambios dirigidos a `staging` y `main`.

Incluye:

* Terraform fmt.  
* Terraform init.  
* TFLint.  
* Gitleaks.  
* Trivy.  
* Terraform validate.  
* Terraform plan.  
* Guardrails destructivos.  
* Infracost opcional.  

## Verificación del backend

Comprobar la cuenta de almacenamiento:

```bash
az storage account show \
  --name stinfralivest01 \
  --resource-group rg-infralive-state \
  --query "{name:name,resourceGroup:resourceGroup,location:primaryLocation}" \
  --output table
```

Comprobar el contenedor:

```bash
az storage container show \
  --name tfstate-staging \
  --account-name stinfralivest01 \
  --auth-mode login \
  --output table
```

Comprobar el state:

```bash
az storage blob list \
  --account-name stinfralivest01 \
  --container-name tfstate-staging \
  --auth-mode login \
  --num-results 1 \
  --output table
```

El state esperado es:

```text
infra-staging.tfstate
```

## Flujo de trabajo

```text
Cambios en Git
      ↓
Pull Request / staging
      ↓
fmt + lint + seguridad + validate
      ↓
terraform plan
      ↓
Revisión del plan
      ↓
Merge a main
      ↓
Aprobación del entorno protegido
      ↓
terraform apply (exclusivo solo para rama main - prod)
      ↓
Verificación de AKS
      ↓
Captura para documentación
      ↓
terraform destroy (exclusivo solo para rama main - prod)
```

La infraestructura de staging sirve para validar la configuración sin mantener recursos costosos desplegados permanentemente. La aplicacion real de AKS se reservará para `main`.

## Estado actual (staging)

- Resource Group: `rg-infraLive-staging`
- Backend de estado Terraform:
  - Storage Account: `stinfralivest01`
  - Container: `tfstate-staging`
  - Configuración: `Infra-staging-tf/backend.tf`
- OIDC (staging): app dedicada con subject
  - `repo:S4M73l09/Az-InfraLive:environment:staging`
- ACR: `infraliveacr` (SKU `Basic`)

## Estructura del repositorio

- `Infra-staging-tf/`
  - `versions.tf`: versión de Terraform/providers
  - `providers.tf`: configuración providers
  - `variables.tf`: variables
  - `main.tf`: recursos
  - `terraform.tfvars`: valores de entorno
- `Custom-roles/`
  - `role-infralive.tpl.json`: definición de rol custom
- `app/`
  - `Dockerfile`: build Astro + runtime Nginx
- `site/`
  - `src/layouts/`: layout base
  - `src/components/`: componentes reutilizables
  - `src/data/catalog.ts`: catálogo centralizado de proyectos/labs
  - `src/pages/index.astro`: hub principal
  - `src/pages/proyectos.astro`: listado de proyectos
  - `src/pages/labs/index.astro`: listado de laboratorios
  - `src/pages/labs/infra.astro`: guía técnica de InfraLive Staging
  - `src/styles/main.css`: estilos globales

## Terraform (staging)

Archivo principal: `Infra-staging-tf/main.tf`

### Recursos declarados y planificados

- VNet: `vnet-infralive-staging` (`10.20.0.0/16`)
- Subnets:
  - `snet-cae` (`10.20.2.0/24`)
  - `snet-pe-staging` (`10.20.3.0/24`)
- Log Analytics: `law-infralive-staging`
- Container Apps:
  - Environment: `cae-infralive-staging`
  - App Nginx privada (ingress interno)
  - Escalado HTTP/KEDA vía `azapi`
- ACR: `infraliveacr`
- ACR Task:
  - Recurso: `azurerm_container_registry_task.nginx_build`
  - Contexto Git: `${var.repo_url}#refs/heads/${var.repo_branch}`
  - Token: `var.repo_token` (solo CI)
- Prometheus/Grafana: bloques comentados para habilitación futura

### Outputs

- `nginx_fqdn`
- `containerapps_env_subnet_id`
- `containerapps_env_internal_lb`
- `acr_login_server`

### Variables clave

- `enable_acr_task`
  - `false` por defecto  
  - `true` en CI para incuirla en la validación y el plan.
- `repo_token`
  - `default = ""`
  - en CI se inyecta con `TF_VAR_repo_token` desde `secrets.REPO_PAT`

### Providers

- `azurerm` `4.57.0`
- `azapi`

## CI/CD

### Workflow principal

Archivo: `.github/workflows/staging.yml`

- Dispara en `staging` o manual (`workflow_dispatch`)
- Login OIDC a Azure
- `fmt`, `init`, `tflint`, `trivy`, `validate`, `plan`
- Artifact de plan (`plan.out`) y summary en workflow
- Guardrails destructivos:
  - bloquea `delete` por defecto
  - bloquea `replace` por defecto
  - bypass manual con:
    - `allow_destroy=true`
    - `allow_replace=true`

### Workflow PR

Archivo: `.github/workflows/pr-staging.yml`

- Checks en PR para `staging/main`
- Incluye `tflint`, `gitleaks`, `trivy`, `infracost` (si hay API key)
- Summary con conteo `+ ~ - ↻`
- Guardrails por labels:
  - `allow-destroy`
  - `allow-replace`
- Variables para ACR Task en CI:
  - `TF_VAR_enable_acr_task: "true"`
  - `TF_VAR_repo_token: ${{ secrets.REPO_PAT }}`

### Workflow de imagen

Archivo: `.github/workflows/build-image.yml`

- Se ejecuta tras `InfraLive Staging` o manualmente
- Lanza build en Azure con:
  - `az acr task run --registry ... --name ...`
- No hace `docker build/push` en el runner
- Funciona tanto para `staging` como para `main`, ademas de verificar el entorno en funcion la rama donde se ejecute.

> Ojo: El workflow valida en staging, pero para optimizar recursos, se valida y despliega en prod (main).

## Metodología

- GitOps: infraestructura declarada en Git y aplicación vía pipelines
- GitSecOps: escaneos de secretos/IaC + controles de cambio destructivo
- Trazabilidad: plan artifacts, summaries y run logs

## Web (Astro)

### Estructura de navegación

- `/`: hub principal
- `/proyectos`: listado de proyectos
- `/labs`: listado de laboratorios
- `/labs/infra`: guía técnica del laboratorio actual

### Diseño y escalabilidad de contenido

- Listados renderizados desde `site/src/data/catalog.ts`
- Componentes reutilizables:
  - `SelectorList`
  - `LaunchNavigationScript`
- Animación visual tipo "launch" al seleccionar tarjetas/listas
- Se puede añadir contenido nuevo sin rehacer diseño (actualizando catálogo + nuevas rutas cuando aplique)

## Desarrollo local (Staging validacion -> main prod)

### Terraform

```bash
cd Infra-staging-tf
terraform init
terraform plan
terraform apply -> exclusivo para main
```

### Astro

```bash
cd site
npm install
npm run dev
```

- `npm install`: instala dependencias
- `npm run dev`: servidor local con recarga en caliente

```bash
npm run build
```

- `npm run build`: genera `site/dist` para servir con Nginx

## Notas operativas

- Si cambias permisos del rol custom:

```bash
sed "s|__SUBSCRIPTION_ID__|<SUBSCRIPTION_ID>|g" \
  Custom-roles/role-infralive.tpl.json \
  > Custom-roles/role-infralive.rendered.json
az role definition update --role-definition Custom-roles/role-infralive.rendered.json
```

- Para ACR Task, el rol custom debe incluir permisos `Microsoft.ContainerRegistry/*`
- Plan local sin token: funciona porque `enable_acr_task=false` por defecto

## Runbook rápido (guard delete/replace)

- No usar bypass por defecto
- Revisar primero diff de plan y summary
- Usar bypass solo con justificación y revisión

### En `staging.yml` (manual)

- `allow_destroy=true` solo para deletes esperados
- `allow_replace=true` solo para replaces esperados

### En `pr-staging.yml` (PR)

- Label `allow-destroy` para habilitar deletes
- Label `allow-replace` para habilitar replaces
- Retirar labels al cerrar/mergear la PR

### Checklist de aprobación

- cambio documentado
- impacto identificado
- rollback definido
- revisión por otra persona
