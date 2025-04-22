output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks_cluster.cluster_id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks_oidc_provider.oidc_provider_arn
}

output "enabled_addons" {
  description = "Map of enabled add-ons with their IAM role ARNs"
  value = {
    aws_load_balancer_controller = local.addons_enabled.aws_load_balancer_controller ? {
      enabled      = true
      iam_role_arn = try(module.aws_load_balancer_controller_iam[0].role_arn, "")
    } : null
    
    karpenter = local.addons_enabled.karpenter ? {
      enabled      = true
      iam_role_arn = try(module.karpenter_iam[0].role_arn, "")
    } : null
    
    cluster_autoscaler = local.addons_enabled.cluster_autoscaler ? {
      enabled      = true
      iam_role_arn = try(module.cluster_autoscaler_iam[0].role_arn, "")
    } : null
    
    keda = local.addons_enabled.keda ? {
      enabled      = true
      iam_role_arn = try(module.keda_iam[0].role_arn, "")
    } : null
    
    external_dns = local.addons_enabled.external_dns ? {
      enabled      = true
      iam_role_arn = try(module.external_dns_iam[0].role_arn, "")
      hosted_zone_id = try(module.external_dns_iam[0].hosted_zone_id, "")
      hosted_zone_name_servers = try(module.external_dns_iam[0].hosted_zone_name_servers, [])
    } : null
    
    prometheus = local.addons_enabled.prometheus ? {
      enabled      = true
      iam_role_arn = try(module.prometheus_iam[0].role_arn, "")
    } : null
    
    secrets_manager = local.addons_enabled.secrets_manager ? {
      enabled      = true
      iam_role_arn = try(module.secrets_manager_iam[0].role_arn, "")
    } : null
    
    cert_manager = local.addons_enabled.cert_manager ? {
      enabled      = true
      iam_role_arn = try(module.cert_manager_iam[0].role_arn, "")
    } : null
    
    nginx_ingress = local.addons_enabled.nginx_ingress ? {
      enabled      = true
      iam_role_arn = try(module.nginx_ingress_iam[0].role_arn, "")
    } : null
    
    adot = local.addons_enabled.adot ? {
      enabled      = true
      iam_role_arn = try(module.adot_iam[0].role_arn, "")
    } : null
    
    fluent_bit = local.addons_enabled.fluent_bit ? {
      enabled      = true
      iam_role_arn = try(module.fluent_bit_iam[0].role_arn, "")
    } : null
  }
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
}

output "eks_managed_node_groups" {
  description = "EKS managed node groups"
  value       = module.eks_cluster.eks_managed_node_groups
}

output "gitlab_integration_status" {
  description = "Status of GitLab pipeline integration"
  value       = var.trigger_gitlab_pipeline ? "enabled" : "disabled"
}