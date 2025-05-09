/**
 * # EKS Cluster with Add-ons
 *
 * This module creates an EKS cluster with managed node groups and optional add-ons.
 * It supports custom launch templates and various IAM role configurations.
 */

provider "aws" {
  region = var.region
}

# Provider for IAM admin role with permissions to create IAM roles and policies
provider "aws" {
  alias  = "iam_admin"
  region = var.region
}

# Get current AWS account ID 
data "aws_caller_identity" "current" {}

locals {
  name = var.cluster_name

  # Determine if using Karpenter or Cluster Autoscaler
  use_karpenter          = var.node_scaling_method == "karpenter"
  use_cluster_autoscaler = var.node_scaling_method == "cluster_autoscaler"

  # Build a map of add-on selections
  addons_enabled = {
    # Core add-ons - always enabled
    ebs_csi_driver = true
    efs_csi_driver = true
    external_dns   = true
    cert_manager   = true

    # Optional add-ons - controlled by both feature flags and global deploy_optional_addons flag
    aws_load_balancer_controller = var.deploy_optional_addons && var.enable_aws_load_balancer_controller
    karpenter                    = var.deploy_optional_addons && local.use_karpenter
    cluster_autoscaler           = var.deploy_optional_addons && local.use_cluster_autoscaler
    keda                         = var.deploy_optional_addons && var.enable_keda
    prometheus                   = var.deploy_optional_addons && var.enable_prometheus
    secrets_manager              = var.deploy_optional_addons && var.enable_secrets_manager
    nginx_ingress                = var.deploy_optional_addons && var.enable_nginx_ingress
    adot                         = var.deploy_optional_addons && var.enable_adot
    fluent_bit                   = var.deploy_optional_addons && var.enable_fluent_bit
  }

  # ComponentID tag that can be enabled/disabled
  component_id_tag = var.component_id_enabled ? { "ComponentID" = var.component_id } : {}

  # Tags
  tags = merge(
    var.tags,
    {
      "ClusterName" = local.name
      "ManagedBy"   = "terraform"
    },
    local.component_id_tag # Add ComponentID tag conditionally
  )

}


# EKS Cluster - create first, then add-ons will reference its OIDC provider
module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name                    = local.name
  cluster_version                 = var.cluster_version
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  control_plane_subnet_ids        = var.control_plane_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  eks_access_entries              = var.eks_access_entries
  component_id                    = var.component_id

  # IAM role configuration - use pre-created roles if specified
  create_cluster_iam_role = var.create_cluster_iam_role
  cluster_iam_role_arn    = var.cluster_iam_role_arn
  create_node_iam_role    = var.create_node_iam_role
  node_iam_role_arn       = var.node_iam_role_arn

  # Node Groups with optional custom AMI
  eks_managed_node_groups = var.eks_managed_node_groups
  node_group_ami_id       = var.node_group_ami_id

  # Basic cluster configuration
  service_ipv4_cidr = var.service_ipv4_cidr
  cluster_ip_family = var.cluster_ip_family

  # Launch template configuration
  use_existing_launch_templates = var.use_existing_launch_templates
  launch_template_arns          = var.launch_template_arns

  # Core add-on IAM role ARNs - these will be created in a separate phase
  # Start with empty values in first apply, then update in second apply
  ebs_csi_driver_role_arn = lookup(var.addon_role_arns, "ebs_csi_driver", "")
  efs_csi_driver_role_arn = lookup(var.addon_role_arns, "efs_csi_driver", "")
  external_dns_role_arn   = lookup(var.addon_role_arns, "external_dns", "")
  cert_manager_role_arn   = lookup(var.addon_role_arns, "cert_manager", "")

  tags = local.tags
}

# Core add-ons - always enabled regardless of feature flags
# These modules will be created after the EKS cluster in a separate apply phase

# EBS CSI Driver - provides persistent storage for pods
module "ebs_csi_driver" {
  source = "./modules/add-ons/ebs-csi-driver"
  count  = var.deploy_addons && local.addons_enabled.ebs_csi_driver ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "ebs_csi_driver", "")
  existing_role_arn = lookup(var.addon_role_arns, "ebs_csi_driver", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }

  depends_on = [module.eks_cluster]
}

# EFS CSI Driver - provides network filesystem storage for pods
module "efs_csi_driver" {
  source = "./modules/add-ons/efs-csi-driver"
  count  = var.deploy_addons && local.addons_enabled.efs_csi_driver ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "efs_csi_driver", "")
  existing_role_arn = lookup(var.addon_role_arns, "efs_csi_driver", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }

  depends_on = [module.eks_cluster]
}

# External DNS - allows automatic DNS records creation/updates
module "external_dns" {
  source = "./modules/add-ons/external-dns"
  count  = var.deploy_addons && local.addons_enabled.external_dns ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "external_dns", "")
  existing_role_arn = lookup(var.addon_role_arns, "external_dns", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }

  depends_on = [module.eks_cluster]
}

# Cert Manager - automates TLS certificate issuance and management
module "cert_manager" {
  source = "./modules/add-ons/cert-manager"
  count  = var.deploy_addons && local.addons_enabled.cert_manager ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "cert_manager", "")
  existing_role_arn = lookup(var.addon_role_arns, "cert_manager", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }

  depends_on = [module.eks_cluster]
}


# Conditional IAM Roles for Add-ons
module "aws_load_balancer_controller_iam" {
  source = "./modules/add-ons/aws-loadbalancer-controller"
  count  = var.deploy_addons && local.addons_enabled.aws_load_balancer_controller ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "aws_load_balancer_controller", "")
  existing_role_arn = lookup(var.addon_role_arns, "aws_load_balancer_controller", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# Karpenter IAM Role (mutually exclusive with Cluster Autoscaler)
module "karpenter_iam" {
  source = "./modules/add-ons/karpenter"
  count  = var.deploy_addons && local.addons_enabled.karpenter ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "karpenter", "")
  existing_role_arn = lookup(var.addon_role_arns, "karpenter", "")

  tags = local.tags
  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# Cluster Autoscaler IAM Role (mutually exclusive with Karpenter)
module "cluster_autoscaler_iam" {
  source = "./modules/add-ons/cluster-autoscaler"
  count  = var.deploy_addons && local.addons_enabled.cluster_autoscaler ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "cluster_autoscaler", "")
  existing_role_arn = lookup(var.addon_role_arns, "cluster_autoscaler", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# KEDA IAM Role
module "keda_iam" {
  source = "./modules/add-ons/keda"
  count  = var.deploy_addons && local.addons_enabled.keda ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "keda", "")
  existing_role_arn = lookup(var.addon_role_arns, "keda", "")

  tags = local.tags
  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# External DNS is now managed directly by the EKS module as a core add-on

module "prometheus_iam" {
  source = "./modules/add-ons/prometheus"
  count  = var.deploy_addons && local.addons_enabled.prometheus ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "prometheus", "")
  existing_role_arn = lookup(var.addon_role_arns, "prometheus", "")

  tags = local.tags
  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# AWS Secrets & Configuration Provider (ASCP)
module "secrets_manager_iam" {
  source = "./modules/add-ons/secrets-manager"
  count  = var.deploy_addons && local.addons_enabled.secrets_manager ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "secrets_manager", "")
  existing_role_arn = lookup(var.addon_role_arns, "secrets_manager", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# Cert Manager is now managed directly by the EKS module as a core add-on

# NGINX Ingress Controller
module "nginx_ingress_iam" {
  source = "./modules/add-ons/nginx-ingress"
  count  = var.deploy_addons && local.addons_enabled.nginx_ingress ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "nginx_ingress", "")
  existing_role_arn = lookup(var.addon_role_arns, "nginx_ingress", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# AWS Distro for OpenTelemetry (ADOT)
module "adot_iam" {
  source = "./modules/add-ons/adot"
  count  = var.deploy_addons && local.addons_enabled.adot ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "adot", "")
  existing_role_arn = lookup(var.addon_role_arns, "adot", "")

  tags = local.tags
  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# Fluent Bit
module "fluent_bit_iam" {
  source = "./modules/add-ons/fluent-bit"
  count  = var.deploy_addons && local.addons_enabled.fluent_bit ? 1 : 0

  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_name      = module.eks_cluster.cluster_name

  # IAM role configuration
  create_role       = var.create_addon_roles
  role_name         = lookup(var.addon_role_names, "fluent_bit", "")
  existing_role_arn = lookup(var.addon_role_arns, "fluent_bit", "")

  tags = local.tags

  providers = {
    aws           = aws
    aws.iam_admin = aws.iam_admin
  }
}

# EBS CSI Driver is now managed directly by the EKS module as a core add-on

# EFS CSI Driver is now managed directly by the EKS module as a core add-on
