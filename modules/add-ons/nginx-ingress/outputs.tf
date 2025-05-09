output "role_arn" {
  description = "ARN of the IAM role for NGINX Ingress Controller"
  value       = var.create_role ? aws_iam_role.nginx[0].arn : var.existing_role_arn
}

output "role_name" {
  description = "Name of the IAM role for NGINX Ingress Controller"
  value       = var.create_role ? aws_iam_role.nginx[0].name : var.role_name
}