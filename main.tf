/**
 * # EKS Cluster with Add-ons
 *
 * This module creates an EKS cluster with managed node groups and optional add-ons.
 * It supports custom launch templates and various IAM role configurations.
 * 
 * Terraform outputs are exported as both JSON and dotenv files for use by GitLab CI/CD child pipelines
 * that handle Helm chart deployments for add-ons.
 */

provider "aws" {
  region = var.region
}

# Provider for IAM admin role with permissions to create IAM roles and policies
provider "aws" {
  alias  = "iam_admin"
  region = var.region
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

}

# Get current AWS account ID 
data "aws_caller_identity" "current" {}

locals {
  name = var.cluster_name

  # Determine if using Karpenter or Cluster Autoscaler
  #use_karpenter          = var.node_scaling_method == "karpenter"
  #use_cluster_autoscaler = var.node_scaling_method == "cluster_autoscaler"

  # Build a map of add-on selections
  addons_enabled = {
    # Core add-ons - always enabled
    #ebs_csi_driver = true
    #efs_csi_driver = true
    #external_dns   = true
    #cert_manager   = true

    # Optional add-ons - controlled by both feature flags and global deploy_optional_addons flag
    #aws_load_balancer_controller = var.deploy_optional_addons && var.enable_aws_load_balancer_controller
    karpenter = var.node_scaling_method == "karpenter"
    #cluster_autoscaler           = var.deploy_optional_addons && local.use_cluster_autoscaler
    #keda                         = var.deploy_optional_addons && var.enable_keda
    #prometheus                   = var.deploy_optional_addons && var.enable_prometheus
    #secrets_manager              = var.deploy_optional_addons && var.enable_secrets_manager
    #nginx_ingress                = var.deploy_optional_addons && var.enable_nginx_ingress
    #adot                         = var.deploy_optional_addons && var.enable_adot
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

  # Karpenter-specific resources for exports (only if Karpenter is enabled)
  karpenter_resources = local.addons_enabled.karpenter ? {
    karpenter_controller_role_arn = module.karpenter[0].controller_iam_role_arn
    karpenter_node_role_arn       = module.karpenter[0].node_role_arn
    karpenter_sqs_queue_name      = module.karpenter[0].sqs_queue_name
    karpenter_instance_profile    = module.karpenter[0].node_instance_profile_name
  } : {}

  # Combine all enabled add-ons for export
  addon_resources = merge(
    {
      cluster_name    = local.name
      aws_region      = var.region
      aws_account_id  = data.aws_caller_identity.current.account_id
    },
    local.karpenter_resources
    # Add other add-on resources here as needed
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
  #ebs_csi_driver_role_arn = lookup(var.addon_role_arns, "ebs_csi_driver", "")
  #efs_csi_driver_role_arn = lookup(var.addon_role_arns, "efs_csi_driver", "")
  #external_dns_role_arn   = lookup(var.addon_role_arns, "external_dns", "")
  #cert_manager_role_arn   = lookup(var.addon_role_arns, "cert_manager", "")

  tags = local.tags
}

# Core add-ons - always enabled regardless of feature flags
# These modules will be created after the EKS cluster in a separate apply phase

# Karpenter module - will be created if node_scaling_method is set to "karpenter"
module "karpenter" {
  count  = local.addons_enabled.karpenter ? 1 : 0
  source = "./modules/karpenter"

  # Ensure this module runs after the EKS cluster is fully deployed
  depends_on = [module.eks_cluster]
  
  cluster_name      = local.name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn

  # Use existing node IAM role if provided
  create_node_iam_role = var.create_node_iam_role
  node_iam_role_arn    = var.create_node_iam_role ? "" : var.node_iam_role_arn
  
  # Controller IAM role settings - use an existing role for IRSA
  create_controller_iam_role = false

  # Create access entry for Karpenter nodes
  create_access_entry = true
  access_entry_type   = "EC2_LINUX"

  # Instance profile settings - create the instance profile using existing role
  create_instance_profile = true

  # Enable SQS queue for spot termination handling
  create_queue = true

  # Additional policies
  attach_ssm_policy        = true
  create_additional_policy = true
  
  # Don't create Spot service-linked role since we only use reserved instances
  create_spot_service_linked_role = false

  tags = local.tags
}


