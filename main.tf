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
    #karpenter                    = var.deploy_optional_addons && local.use_karpenter
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



