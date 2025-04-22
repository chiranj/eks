output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks_cluster_module.cluster_id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_cluster_module.cluster_arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API"
  value       = module.eks_cluster_module.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_cluster_module.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_cluster_module.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks_cluster_module.oidc_provider_arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.eks_cluster_module.vpc_id
}

output "enabled_addons" {
  description = "Map of enabled add-ons with their IAM role ARNs"
  value       = module.eks_cluster_module.enabled_addons
}