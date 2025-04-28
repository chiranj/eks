output "role_arn" {
  description = "ARN of the IAM role for EFS CSI Driver"
  value       = aws_iam_role.efs_csi.arn
}

output "role_name" {
  description = "Name of the IAM role for EFS CSI Driver"
  value       = aws_iam_role.efs_csi.name
}