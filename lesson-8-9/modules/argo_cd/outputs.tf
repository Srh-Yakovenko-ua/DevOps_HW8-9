output "namespace" {
  description = "Namespace Argo CD runs in"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "application_name" {
  description = "Name of the Argo CD Application that tracks the Dealsbe chart"
  value       = var.app_name
}

output "server_url_command" {
  description = "Command that prints the Argo CD UI URL once the LoadBalancer is assigned"
  value       = "kubectl -n ${var.namespace} get svc ${var.release_name}-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{\"\\n\"}'"
}

output "admin_password_command" {
  description = "Command that prints the initial Argo CD admin password (user: admin)"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}
