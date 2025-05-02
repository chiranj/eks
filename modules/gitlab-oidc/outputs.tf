output "role_arn" {
  description = "ARN of the IAM role for GitLab CI/CD"
  value       = aws_iam_role.gitlab_deployment_role.arn
}

output "role_name" {
  description = "Name of the IAM role for GitLab CI/CD"
  value       = aws_iam_role.gitlab_deployment_role.name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.gitlab[0].arn : data.aws_iam_openid_connect_provider.gitlab[0].arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = "https://${local.gitlab_host}"
}