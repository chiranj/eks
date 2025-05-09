output "role_arn" {
  description = "ARN of the IAM role for EFS CSI Driver"
  value       = var.create_role ? aws_iam_role.efs_csi[0].arn : var.existing_role_arn
}

output "role_name" {
  description = "Name of the IAM role for EFS CSI Driver"
  value       = var.create_role ? aws_iam_role.efs_csi[0].name : var.role_name
}