output "role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = var.create_role ? aws_iam_role.external_dns[0].arn : var.existing_role_arn
}

output "role_name" {
  description = "Name of the IAM role for External DNS"
  value       = var.create_role ? aws_iam_role.external_dns[0].name : var.role_name
}

output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone (if created)"
  value       = local.create_hosted_zone ? aws_route53_zone.zone[0].id : var.existing_hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers of the Route53 hosted zone (if created)"
  value       = local.create_hosted_zone ? aws_route53_zone.zone[0].name_servers : []
}