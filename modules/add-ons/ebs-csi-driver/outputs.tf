output "role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "role_name" {
  description = "Name of the IAM role for EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.name
}