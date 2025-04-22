output "role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role for External DNS"
  value       = aws_iam_role.this.name
}

output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone used by External DNS"
  value       = local.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the Route53 hosted zone (only available if a new zone was created)"
  value       = local.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}