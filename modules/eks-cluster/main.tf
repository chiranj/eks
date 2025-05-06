/**
 * # EKS Cluster Module
 * 
 * This module creates an Amazon EKS cluster with node groups.
 */

locals {
  name = var.cluster_name

  # DNS cluster IP based on service CIDR
  dns_cluster_ip = cidrhost(var.service_ipv4_cidr, 10)

  # Extract launch template details from ARNs for pre-created templates
  launch_template_data = {
    for name, arn in var.launch_template_arns : name => {
      # ARN format: arn:aws:ec2:region:account-id:launch-template/lt-id
      name = reverse(split("/", arn))[0]
      id   = reverse(split("/", arn))[0]
    } if contains(keys(var.eks_managed_node_groups), name)
  }

  # User data is handled directly in the prepared_eks_managed_node_groups local

  # =================================================================
  # ROLLBACK POINT: This is a simplified approach using EKS-managed launch templates
  # If you need to go back to the previous implementation, please see git history
  # =================================================================
  
  # Let EKS fully manage the node groups and launch templates
  # This approach has EKS create and manage the launch templates with proper permissions
  # We're using the simplest possible configuration to avoid permission issues
  managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => {
      # Basic node group configuration
      name           = lookup(group, "name", name)
      min_size       = lookup(group, "min_size", 1)
      max_size       = lookup(group, "max_size", 3)
      desired_size   = lookup(group, "desired_size", 2)
      instance_types = lookup(group, "instance_types", ["t3.medium"])
      capacity_type  = lookup(group, "capacity_type", "ON_DEMAND")
      
      # Basic disk size setting
      disk_size = lookup(group, "disk_size", 50)
      
      # Labels and tags
      labels = lookup(group, "labels", {})
      
      # Add required organizational tags
      # The error message shows a requirement for ComponentID tag
      tags = merge(
        lookup(group, "tags", {}),
        {
          # Required per organization policy "DenyWithNoCompTag"
          "ComponentID" = var.component_id
        }
      )
      
      # Handle custom AMI - use custom_ami_id to let EKS create the launch template
      # When using custom_ami_id, ami_type must be null
      ami_type      = lookup(group, "custom_ami_id", null) != null ? null : lookup(group, "ami_type", "AL2_x86_64")
      custom_ami_id = lookup(group, "custom_ami_id", null)
      
      # Pass bootstrap arguments but let EKS handle all the user data
      bootstrap_extra_args = lookup(group, "bootstrap_extra_args", "")
      
      # IAM role settings - use AWS managed policies for node groups
      create_iam_role = var.create_node_iam_role
      iam_role_arn    = var.create_node_iam_role ? null : var.node_iam_role_arn
    }
  }
}

# ROLLBACK POINT: Custom IAM policy removed
# When using EKS-managed launch templates, we don't need this custom policy
# as EKS will use its service-linked role to create and manage the launch templates
#
# If you need to roll back to custom launch templates, uncomment and restore this policy:
/*
resource "aws_iam_policy" "launch_template_access" {
  name        = "${local.name}-ec2-full-access"
  description = "Provides all necessary EC2 permissions for EKS node groups with custom AMIs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 permissions omitted for brevity - see git history for full policy
        ]
        Resource = "*"
      }
    ]
  })
}
*/

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = local.name
  cluster_version                 = var.cluster_version
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  control_plane_subnet_ids        = var.control_plane_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # IAM role configuration for cluster
  create_iam_role = var.create_cluster_iam_role
  iam_role_arn    = var.create_cluster_iam_role ? null : var.cluster_iam_role_arn

  # Always create security group
  create_node_security_group = true

  # =================================================================
  # ROLLBACK POINT: Using EKS-managed node groups with standard AWS policies
  # =================================================================
  
  # Standard AWS managed policies for EKS node groups
  # Note: We removed the custom EC2FullAccess policy since EKS will handle permissions
  iam_role_additional_policies = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  
  # Standard EKS cluster settings
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 90
  cluster_enabled_log_types              = ["api", "audit", "authenticator"]
  cluster_security_group_name            = "${local.name}-cluster-sg"
  node_security_group_name               = "${local.name}-node-sg"
  
  # Organizational tagging requirements and volume configuration
  # The decoded error shows we need a ComponentID tag on EC2 resources
  # And we need to use gp3 volumes instead of gp2, with encryption enabled
  eks_managed_node_group_defaults = {
    # Ensure tags are added to all resources created for node groups
    # This addresses the organization policy "DenyWithNoCompTag"
    tags = {
      "ComponentID" = var.component_id
    }
    
    # Block device configuration for all node groups
    # Using gp3 instead of gp2 (as required by organization policy "DenyVolumeTypegp2")
    # And enabling encryption (as required by policy "EC2VolumeDenyWithoutEncryption")
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"  # Using gp3 instead of gp2
          iops                  = 3000
          throughput            = 150
          encrypted             = true   # Enable encryption for all volumes
          delete_on_termination = true
        }
      }
    }
  }
  
  # Use our simplified managed node groups configuration
  # This lets EKS handle launch template creation with proper permissions
  eks_managed_node_groups = local.managed_node_groups

  # Cluster IP family
  cluster_ip_family = var.cluster_ip_family

  # Service CIDR
  cluster_service_ipv4_cidr = var.service_ipv4_cidr

  # Access management (v20+ uses access entries instead of aws-auth ConfigMap)
  authentication_mode = "API_AND_CONFIG_MAP"

  # Use custom access entries if provided, otherwise convert legacy aws_auth_roles
  access_entries = length(var.eks_access_entries) > 0 ? var.eks_access_entries : {
    for i, role in var.aws_auth_roles : "role-${i}" => {
      principal_arn = lookup(role, "rolearn", "")
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    } if lookup(role, "rolearn", "") != ""
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Enable OIDC provider
  enable_irsa = true

  tags = var.tags
}