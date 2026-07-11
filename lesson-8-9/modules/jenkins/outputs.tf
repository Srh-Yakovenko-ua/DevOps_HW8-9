output "namespace" {
  description = "Namespace Jenkins runs in"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "release_name" {
  description = "Helm release / Service name of the Jenkins controller"
  value       = helm_release.jenkins.name
}

output "agent_role_arn" {
  description = "ARN of the IRSA role the build agents use to push to ECR"
  value       = aws_iam_role.agent.arn
}

output "job_name" {
  description = "Name of the pipeline job created by the JCasC seed"
  value       = var.job_name
}

output "url_command" {
  description = "Command that prints the Jenkins UI URL once the LoadBalancer is assigned"
  value       = "kubectl -n ${var.namespace} get svc ${var.release_name} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{\"\\n\"}'"
}

output "admin_password_command" {
  description = "Command that prints the Jenkins admin password"
  value       = "kubectl -n ${var.namespace} get secret ${var.release_name} -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo"
}
