output "controller_iam_role_arn" {
  description = "ARN of the Karpenter controller IAM role (for IRSA)"
  value       = module.karpenter.iam_role_arn
}

output "controller_iam_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = module.karpenter.iam_role_name
}

output "sqs_queue_name" {
  description = "Name of the SQS queue for interruption handling"
  value       = module.karpenter.queue_name
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for interruption handling"
  value       = module.karpenter.queue_arn
}

output "node_instance_profile_name" {
  description = "Name of the node instance profile"
  value       = module.karpenter.instance_profile_name
}

output "node_instance_profile_arn" {
  description = "ARN of the node instance profile"
  value       = module.karpenter.instance_profile_arn
}

output "node_role_arn" {
  description = "ARN of the node IAM role used by Karpenter"
  value       = var.node_iam_role_arn != "" ? var.node_iam_role_arn : module.karpenter.node_iam_role_arn
}

output "node_role_name" {
  description = "Name of the node IAM role used by Karpenter"
  value       = var.node_iam_role_arn != "" ? reverse(split("/", var.node_iam_role_arn))[0] : module.karpenter.node_iam_role_name
}