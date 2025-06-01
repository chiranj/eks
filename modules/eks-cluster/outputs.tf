output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "eks_managed_node_groups" {
  description = "EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

output "custom_launch_templates" {
  description = "Launch templates created for node groups with custom AMIs (now handled by EKS module)"
  value       = {}
}

output "cluster_addons" {
  description = "Map of installed EKS cluster add-ons"
  value       = module.eks.cluster_addons
}

output "ebs_csi_driver_enabled" {
  description = "Whether EBS CSI Driver add-on is enabled (always true)"
  value       = true
}

output "efs_csi_driver_enabled" {
  description = "Whether EFS CSI Driver add-on is enabled (always true)"
  value       = true
}

output "external_dns_enabled" {
  description = "Whether External DNS add-on is enabled (always true)"
  value       = true
}

output "cert_manager_enabled" {
  description = "Whether Cert Manager add-on is enabled (always true)"
  value       = true
}

# Core add-on IAM role ARNs (pass-through from input variables)
output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = var.ebs_csi_driver_role_arn
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EFS CSI Driver"
  value       = var.efs_csi_driver_role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = var.external_dns_role_arn
}

output "cert_manager_role_arn" {
  description = "ARN of the IAM role for Cert Manager"
  value       = var.cert_manager_role_arn
}
