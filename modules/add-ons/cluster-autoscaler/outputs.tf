output "role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = local.role_arn
}

output "role_name" {
  description = "Name of the IAM role for Cluster Autoscaler"
  value       = local.role_name
}