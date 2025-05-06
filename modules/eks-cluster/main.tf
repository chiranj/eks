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

  # Completely revamp our node group approach to avoid launch templates entirely
  # Instead, use the native AMI support directly in the Terraform AWS EKS module
  managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => {
      # Pass through all base configurations
      name = lookup(group, "name", name)
      
      # Use sensible defaults for scaling
      min_size     = lookup(group, "min_size", 1)
      max_size     = lookup(group, "max_size", 3) 
      desired_size = lookup(group, "desired_size", 2)
      
      # Instance configurations
      instance_types = lookup(group, "instance_types", ["t3.medium"])
      capacity_type  = lookup(group, "capacity_type", "ON_DEMAND")
      disk_size      = lookup(group, "disk_size", 50)
      
      # Labels and metadata
      labels = lookup(group, "labels", {})
      tags   = lookup(group, "tags", {})
      
      # Custom AMI ID handling
      # We need to set ami_type to null when using custom_ami_id
      # This directly uses EKS API attributes without launch templates
      ami_type = lookup(group, "custom_ami_id", null) != null ? null : lookup(group, "ami_type", "AL2_x86_64")
      
      # Only pass custom_ami_id if it's provided, otherwise omit it
      custom_ami_id = lookup(group, "custom_ami_id", null)
            
      # IAM settings
      create_iam_role = var.create_node_iam_role
      iam_role_arn    = var.create_node_iam_role ? null : var.node_iam_role_arn
      
      # Block device mappings
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = lookup(group, "disk_size", 50)
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
      
      # Handle bootstrap arguments for AWS-provided AMIs (no custom user data)
      bootstrap_extra_args = lookup(group, "bootstrap_extra_args", "")
      
      # For custom AMIs, we use a simpler technique - avoid all templating issues
      pre_bootstrap_user_data = ""
      
      # Remote access configuration (empty map instead of null to avoid errors)
      remote_access = {}
    }
  }
}

# Create a dedicated IAM policy with comprehensive EC2 permissions
# This ensures the node group role has all necessary permissions to launch instances
resource "aws_iam_policy" "launch_template_access" {
  name        = "${local.name}-ec2-full-access"
  description = "Provides all necessary EC2 permissions for EKS node groups with custom AMIs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Launch instance permissions
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:TerminateInstances",
          
          # Launch template permissions
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:ModifyLaunchTemplate",
          "ec2:StartInstances",
          "ec2:StopInstances",
          
          # AMI/Image permissions
          "ec2:DescribeImages",
          "ec2:DescribeImageAttribute",
          
          # Network interface permissions
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          
          # Security group permissions
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          
          # Subnet permissions
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeRouteTables",
          
          # Volume permissions
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeAttribute",
          
          # Instance Type
          "ec2:DescribeInstanceTypes",
          
          # Tag permissions
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

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

  # Use our completely revised approach to node groups
  # Instead of using launch templates, we directly configure the node groups
  # with custom AMIs using EKS's native custom_ami_id support
  
  # These permissions apply to all node groups
  iam_role_additional_policies = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    # Add EC2 instance and launch template permissions
    EC2FullAccess = aws_iam_policy.launch_template_access.arn
  }
  
  # Global EKS cluster-level settings
  create_cloudwatch_log_group   = true
  cloudwatch_log_group_retention_in_days = 90
  cluster_enabled_log_types     = ["api", "audit", "authenticator"]
  cluster_security_group_name   = "${local.name}-cluster-sg"
  node_security_group_name      = "${local.name}-node-sg"
  
  # Use our managed node groups directly - skipping launch templates
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