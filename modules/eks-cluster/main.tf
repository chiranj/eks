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

  # Simplified direct node group configuration
  # This avoids the complex launch template handling that can cause permission issues
  prepared_eks_managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => merge(
      # First include all base configuration
      group,

      # For custom AMIs, add necessary configuration
      lookup(group, "ami_id", "") != "" ? {
        # Set proper AMI configuration 
        create_launch_template = true

        # Provide user data directly at the top level
        user_data_template_override = templatefile("${path.module}/templates/user-data.sh", {
          cluster_name               = local.name
          cluster_endpoint           = module.eks.cluster_endpoint
          certificate_authority_data = module.eks.cluster_certificate_authority_data
          service_ipv4_cidr          = var.service_ipv4_cidr
          dns_cluster_ip             = local.dns_cluster_ip
          bootstrap_extra_args       = lookup(group, "bootstrap_extra_args", "")
          kubelet_extra_args         = lookup(group, "kubelet_extra_args", "")
          extra_kubelet_args         = lookup(group, "kubelet_extra_args", "")
        })
      } : {},

      # Handle pre-created launch templates if specified
      var.use_existing_launch_templates && contains(keys(var.launch_template_arns), name) ? {
        create_launch_template = false
        launch_template_id     = reverse(split("/", var.launch_template_arns[name]))[0]
      } : {},

      # IAM role configuration (if using pre-created role)
      !var.create_node_iam_role ? {
        create_iam_role = false
        iam_role_arn    = var.node_iam_role_arn
      } : {}
    )
  }
}

# Create a dedicated IAM policy for launch template access 
# This policy grants necessary permissions to work with launch templates to avoid the
# "You are not authorized to launch instances with this launch template" error
resource "aws_iam_policy" "launch_template_access" {
  name        = "${local.name}-launch-template-access"
  description = "Provides necessary permissions to use launch templates with EKS node groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:ModifyLaunchTemplate",
          "ec2:CreateTags"
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

  # Configure node groups with strong defaults to ensure proper permissions
  eks_managed_node_group_defaults = {
    # Ensure IAM permissions are correctly configured
    iam_role_additional_policies = {
      AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      # Include specific EC2 permissions for launch templates to resolve the authorization error
      # We create this policy inline below to avoid creating an additional resource
      EC2LaunchTemplateFullAccess = aws_iam_policy.launch_template_access.arn
    }

    # Define our extra IAM configuration
    iam_role_name        = "${local.name}-eks-node-group-role"
    iam_role_description = "EKS managed node group role for cluster ${local.name}"

    # Set proper block device mappings for all node groups
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"
          delete_on_termination = true
        }
      }
    }

    # Default metadata settings to ensure security best practices
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }
  }

  # Use our simplified node group configuration
  eks_managed_node_groups = local.prepared_eks_managed_node_groups

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