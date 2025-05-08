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
  description = "The ARN of the OIDC Provider for the EKS cluster"
  value       = local.oidc_provider_arn
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
      enabled                  = true
      iam_role_arn             = try(module.external_dns_iam[0].role_arn, "")
      hosted_zone_id           = try(module.external_dns_iam[0].hosted_zone_id, "")
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

    ebs_csi_driver = local.addons_enabled.ebs_csi_driver ? {
      enabled              = true
      iam_role_arn         = try(module.ebs_csi_driver_iam[0].role_arn, "")
      is_eks_managed_addon = true
    } : null

    efs_csi_driver = local.addons_enabled.efs_csi_driver ? {
      enabled              = true
      iam_role_arn         = try(module.efs_csi_driver_iam[0].role_arn, "")
      is_eks_managed_addon = true
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

output "gitlab_deployment_role_arn" {
  description = "ARN of the GitLab deployment role that has access to the EKS cluster"
  value       = local.gitlab_role_arn
}

output "gitlab_integration_env_file_path" {
  description = "Path to the environment variables file for GitLab parent-child pipeline integration"
  value       = var.trigger_gitlab_pipeline ? try(module.gitlab_integration[0].env_file_path, "") : ""
}

output "gitlab_integration_json_file_path" {
  description = "Path to the JSON configuration file for GitLab parent-child pipeline integration"
  value       = var.trigger_gitlab_pipeline ? try(module.gitlab_integration[0].json_file_path, "") : ""
}

# Individual IAM role ARN outputs for easy access
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = local.addons_enabled.aws_load_balancer_controller ? try(module.aws_load_balancer_controller_iam[0].role_arn, "") : ""
}

output "karpenter_role_arn" {
  description = "ARN of the IAM role for Karpenter"
  value       = local.addons_enabled.karpenter ? try(module.karpenter_iam[0].role_arn, "") : ""
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = local.addons_enabled.cluster_autoscaler ? try(module.cluster_autoscaler_iam[0].role_arn, "") : ""
}

output "keda_role_arn" {
  description = "ARN of the IAM role for KEDA"
  value       = local.addons_enabled.keda ? try(module.keda_iam[0].role_arn, "") : ""
}

output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = local.addons_enabled.external_dns ? try(module.external_dns_iam[0].role_arn, "") : ""
}

output "prometheus_role_arn" {
  description = "ARN of the IAM role for Prometheus"
  value       = local.addons_enabled.prometheus ? try(module.prometheus_iam[0].role_arn, "") : ""
}

output "secrets_manager_role_arn" {
  description = "ARN of the IAM role for Secrets Manager"
  value       = local.addons_enabled.secrets_manager ? try(module.secrets_manager_iam[0].role_arn, "") : ""
}

output "cert_manager_role_arn" {
  description = "ARN of the IAM role for Cert Manager"
  value       = local.addons_enabled.cert_manager ? try(module.cert_manager_iam[0].role_arn, "") : ""
}

output "nginx_ingress_role_arn" {
  description = "ARN of the IAM role for NGINX Ingress Controller"
  value       = local.addons_enabled.nginx_ingress ? try(module.nginx_ingress_iam[0].role_arn, "") : ""
}

output "adot_role_arn" {
  description = "ARN of the IAM role for ADOT"
  value       = local.addons_enabled.adot ? try(module.adot_iam[0].role_arn, "") : ""
}

output "fluent_bit_role_arn" {
  description = "ARN of the IAM role for Fluent Bit"
  value       = local.addons_enabled.fluent_bit ? try(module.fluent_bit_iam[0].role_arn, "") : ""
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = local.addons_enabled.ebs_csi_driver ? try(module.ebs_csi_driver_iam[0].role_arn, "") : ""
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EFS CSI Driver"
  value       = local.addons_enabled.efs_csi_driver ? try(module.efs_csi_driver_iam[0].role_arn, "") : ""
}

output "cluster_addons" {
  description = "Map of installed EKS cluster add-ons"
  value       = module.eks_cluster.cluster_addons
}