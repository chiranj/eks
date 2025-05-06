/**
 * # AWS Service Catalog - EKS Cluster with Add-ons
 *
 * This module creates an EKS cluster with optional add-ons using AWS Service Catalog.
 */

provider "aws" {
  region = var.region
}

locals {
  name       = var.cluster_name
  create_vpc = var.vpc_mode == "create_new"

  # Determine if using Karpenter or Cluster Autoscaler
  use_karpenter          = var.node_scaling_method == "karpenter"
  use_cluster_autoscaler = var.node_scaling_method == "cluster_autoscaler"

  # Build a map of add-on selections
  addons_enabled = {
    aws_load_balancer_controller = var.enable_aws_load_balancer_controller
    karpenter                    = local.use_karpenter
    cluster_autoscaler           = local.use_cluster_autoscaler
    keda                         = var.enable_keda
    external_dns                 = var.enable_external_dns
    prometheus                   = var.enable_prometheus
    secrets_manager              = var.enable_secrets_manager
    cert_manager                 = var.enable_cert_manager
    nginx_ingress                = var.enable_nginx_ingress
    adot                         = var.enable_adot
    fluent_bit                   = var.enable_fluent_bit
    ebs_csi_driver               = var.enable_ebs_csi_driver
    efs_csi_driver               = var.enable_efs_csi_driver
  }

  # Tags
  tags = merge(
    var.tags,
    {
      "ClusterName" = local.name
      "ManagedBy"   = "terraform"
    }
  )
}

# Create VPC if specified
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  count   = local.create_vpc ? 1 : 0

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# GitLab role ARN is now expected to be provided directly
# No longer creating GitLab OIDC provider and role automatically

# Determine the GitLab role ARN to use
locals {
  # Now we just use the provided gitlab_aws_role_arn
  gitlab_role_arn = var.gitlab_aws_role_arn

  # Add GitLab role to access entries if it exists
  eks_access_entries_with_gitlab = local.gitlab_role_arn != "" ? merge(
    var.eks_access_entries,
    {
      gitlab-deployment = {
        principal_arn = local.gitlab_role_arn
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }
  ) : var.eks_access_entries
}

# EKS Cluster
module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name                    = local.name
  cluster_version                 = var.cluster_version
  vpc_id                          = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  subnet_ids                      = local.create_vpc ? module.vpc[0].private_subnets : var.subnet_ids
  control_plane_subnet_ids        = local.create_vpc ? module.vpc[0].public_subnets : var.control_plane_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  eks_access_entries              = local.eks_access_entries_with_gitlab

  # IAM role configuration - use pre-created roles if specified
  create_cluster_iam_role = var.create_cluster_iam_role
  cluster_iam_role_arn    = var.cluster_iam_role_arn
  create_node_iam_role    = var.create_node_iam_role
  node_iam_role_arn       = var.node_iam_role_arn

  # Node Groups with optional custom AMI
  eks_managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => merge(
      group,
      var.node_group_ami_id != "" && !contains(keys(group), "custom_ami_id") ?
      { custom_ami_id = var.node_group_ami_id } : {}
    )
  }

  # Basic cluster configuration
  service_ipv4_cidr = var.service_ipv4_cidr
  cluster_ip_family = var.cluster_ip_family

  # We're now letting the EKS module handle launch template creation
  # Only passing these variables for the rare case where someone wants to use
  # a pre-created launch template instead of having the module create one
  use_existing_launch_templates = var.use_existing_launch_templates
  launch_template_arns          = var.launch_template_arns

  tags = local.tags
}

# OIDC Provider for EKS
module "eks_oidc_provider" {
  source = "./modules/oidc-provider"

  cluster_name = module.eks_cluster.cluster_name
  oidc_url     = module.eks_cluster.cluster_oidc_issuer_url

  tags = local.tags
}

# Conditional IAM Roles for Add-ons
module "aws_load_balancer_controller_iam" {
  source = "./modules/add-ons/aws-loadbalancer-controller"
  count  = local.addons_enabled.aws_load_balancer_controller ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Karpenter IAM Role (mutually exclusive with Cluster Autoscaler)
module "karpenter_iam" {
  source = "./modules/add-ons/karpenter"
  count  = local.addons_enabled.karpenter ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Cluster Autoscaler IAM Role (mutually exclusive with Karpenter)
module "cluster_autoscaler_iam" {
  source = "./modules/add-ons/cluster-autoscaler"
  count  = local.addons_enabled.cluster_autoscaler ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# KEDA IAM Role
module "keda_iam" {
  source = "./modules/add-ons/keda"
  count  = local.addons_enabled.keda ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

module "external_dns_iam" {
  source = "./modules/add-ons/external-dns"
  count  = local.addons_enabled.external_dns ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # Hosted zone configuration
  hosted_zone_source      = var.external_dns_hosted_zone_source
  existing_hosted_zone_id = var.external_dns_existing_hosted_zone_id
  domain                  = var.external_dns_domain

  tags = local.tags
}

module "prometheus_iam" {
  source = "./modules/add-ons/prometheus"
  count  = local.addons_enabled.prometheus ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# AWS Secrets & Configuration Provider (ASCP)
module "secrets_manager_iam" {
  source = "./modules/add-ons/secrets-manager"
  count  = local.addons_enabled.secrets_manager ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Cert Manager
module "cert_manager_iam" {
  source = "./modules/add-ons/cert-manager"
  count  = local.addons_enabled.cert_manager ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# NGINX Ingress Controller
module "nginx_ingress_iam" {
  source = "./modules/add-ons/nginx-ingress"
  count  = local.addons_enabled.nginx_ingress ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# AWS Distro for OpenTelemetry (ADOT)
module "adot_iam" {
  source = "./modules/add-ons/adot"
  count  = local.addons_enabled.adot ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Fluent Bit
module "fluent_bit_iam" {
  source = "./modules/add-ons/fluent-bit"
  count  = local.addons_enabled.fluent_bit ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Amazon EBS CSI Driver
module "ebs_csi_driver_iam" {
  source = "./modules/add-ons/ebs-csi-driver"
  count  = local.addons_enabled.ebs_csi_driver ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# Amazon EFS CSI Driver
module "efs_csi_driver_iam" {
  source = "./modules/add-ons/efs-csi-driver"
  count  = local.addons_enabled.efs_csi_driver ? 1 : 0

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  tags = local.tags
}

# GitLab Pipeline Integration
module "gitlab_integration" {
  source = "./modules/gitlab-integration"
  count  = var.trigger_gitlab_pipeline ? 1 : 0

  aws_role_arn = local.gitlab_role_arn

  cluster_name      = module.eks_cluster.cluster_name
  cluster_endpoint  = module.eks_cluster.cluster_endpoint
  cluster_ca_data   = module.eks_cluster.cluster_certificate_authority_data
  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn

  # Add-on selections and IAM roles
  addons_config = {
    aws_load_balancer_controller = local.addons_enabled.aws_load_balancer_controller ? {
      enabled      = true
      iam_role_arn = try(module.aws_load_balancer_controller_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    karpenter = local.addons_enabled.karpenter ? {
      enabled      = true
      iam_role_arn = try(module.karpenter_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    cluster_autoscaler = local.addons_enabled.cluster_autoscaler ? {
      enabled      = true
      iam_role_arn = try(module.cluster_autoscaler_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    keda = local.addons_enabled.keda ? {
      enabled      = true
      iam_role_arn = try(module.keda_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    external_dns = local.addons_enabled.external_dns ? {
      enabled                  = true
      iam_role_arn             = try(module.external_dns_iam[0].role_arn, "")
      hosted_zone_id           = try(module.external_dns_iam[0].hosted_zone_id, "")
      hosted_zone_name_servers = try(module.external_dns_iam[0].hosted_zone_name_servers, [])
    } : { enabled = false, iam_role_arn = "", hosted_zone_id = "", hosted_zone_name_servers = [] }

    prometheus = local.addons_enabled.prometheus ? {
      enabled      = true
      iam_role_arn = try(module.prometheus_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    secrets_manager = local.addons_enabled.secrets_manager ? {
      enabled      = true
      iam_role_arn = try(module.secrets_manager_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    cert_manager = local.addons_enabled.cert_manager ? {
      enabled      = true
      iam_role_arn = try(module.cert_manager_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    nginx_ingress = local.addons_enabled.nginx_ingress ? {
      enabled      = true
      iam_role_arn = try(module.nginx_ingress_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    adot = local.addons_enabled.adot ? {
      enabled      = true
      iam_role_arn = try(module.adot_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }

    fluent_bit = local.addons_enabled.fluent_bit ? {
      enabled      = true
      iam_role_arn = try(module.fluent_bit_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" },

    ebs_csi_driver = local.addons_enabled.ebs_csi_driver ? {
      enabled      = true
      iam_role_arn = try(module.ebs_csi_driver_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" },

    efs_csi_driver = local.addons_enabled.efs_csi_driver ? {
      enabled      = true
      iam_role_arn = try(module.efs_csi_driver_iam[0].role_arn, "")
    } : { enabled = false, iam_role_arn = "" }
  }

  depends_on = [
    module.eks_cluster,
    module.eks_oidc_provider,
    module.aws_load_balancer_controller_iam,
    module.karpenter_iam,
    module.cluster_autoscaler_iam,
    module.keda_iam,
    module.external_dns_iam,
    module.prometheus_iam,
    module.secrets_manager_iam,
    module.cert_manager_iam,
    module.nginx_ingress_iam,
    module.adot_iam,
    module.fluent_bit_iam,
    module.ebs_csi_driver_iam,
    module.efs_csi_driver_iam
  ]
}