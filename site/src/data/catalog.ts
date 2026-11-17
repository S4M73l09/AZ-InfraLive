export type CatalogItem = {
  label: string;
  title: string;
  description: string;
  href?: string;
  state?: "active" | "ghost";
};

export const projectItems: CatalogItem[] = [
  {
    label: "Proximamente",
    title: "Proyecto #1",
    description: "Documentacion en camino",
    state: "ghost",
  },
  {
    label: "Proximamente",
    title: "Proyecto #2",
    description: "Nueva guia tecnica en preparacion",
    state: "ghost",
  },
  {
    label: "Proximamente",
    title: "Proyecto #3",
    description: "Laboratorio adicional en cloud",
    state: "ghost",
  },
];

export const labItems: CatalogItem[] = [
  {
    label: "Disponible",
    title: "InfraLive Staging",
    description: "Azure, Terraform, seguridad CI/CD y ACR Task",
    href: "/labs/infra",
    state: "active",
  },
  {
    label: "Proximamente",
    title: "InfraLive Production",
    description: "Hardening y despliegue final",
    state: "ghost",
  },
  {
    label: "Proximamente",
    title: "Observabilidad avanzada",
    description: "Metricas, alertas y trazabilidad",
    state: "ghost",
  },
];
