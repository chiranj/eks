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

  # Generate user data for each node group that will have a custom AMI
  # This ensures bootstrap scripts have the right cluster information
  node_group_user_data = {
    for name, group in var.eks_managed_node_groups :
    name => base64encode(templatefile("${path.module}/templates/user-data.sh", {
      cluster_name               = local.name
      cluster_endpoint           = module.eks.cluster_endpoint
      certificate_authority_data = module.eks.cluster_certificate_authority_data
      service_ipv4_cidr          = var.service_ipv4_cidr
      dns_cluster_ip             = local.dns_cluster_ip
      bootstrap_extra_args       = lookup(group, "bootstrap_extra_args", "")
      kubelet_extra_args         = lookup(group, "kubelet_extra_args", "")
      extra_kubelet_args         = lookup(group, "kubelet_extra_args", "") # Duplicate for compatibility with template
    })) if lookup(group, "ami_id", "") != ""
  }

  # Prepare node groups configuration with a simpler approach
  # Let the EKS module create properly authorized launch templates
  eks_managed_node_group_configs = {
    for name, group in var.eks_managed_node_groups : name => merge(
      # Base configuration without ami_id (will be handled separately)
      {
        for k, v in group : k => v if k != "ami_id"
      },
      
      # Only add these for groups with custom AMIs
      lookup(group, "ami_id", "") != "" ? {
        # Set create_launch_template to true to have EKS module handle it
        create_launch_template = true
        
        # Launch template configuration for custom AMI
        launch_template_name = ""
        launch_template_id = ""
        launch_template_version = ""
      } : {},
      
      # Pre-created launch templates (if specified)
      var.use_existing_launch_templates && contains(keys(var.launch_template_arns), name) ? {
        create_launch_template = false
        launch_template_id = lookup(local.launch_template_data, name, {}).id
      } : {},
      
      # IAM role configuration (if using pre-created role)
      !var.create_node_iam_role ? {
        create_iam_role = false
        iam_role_arn    = var.node_iam_role_arn
        # Ensure these IAM role related settings are explicitly set with empty values
        # This helps maintain consistent types across all conditional branches
        iam_role_name = ""
        iam_role_path = ""
        iam_role_permissions_boundary = ""
      } : {}
    )
  }
  
  # Custom configuration for launch templates
  # This properly handles the launch template configuration without type issues
  eks_managed_node_group_launch_templates = {
    for name, group in var.eks_managed_node_groups : 
    name => lookup(group, "ami_id", "") != "" ? [{
      # Custom AMI configuration
      ami_id = lookup(group, "ami_id", "")
      
      # Set proper tags for the instances
      instance_tags = {
        "kubernetes.io/cluster/${local.name}" = "owned"
      }
      
      # Add proper configuration for cluster access
      user_data = lookup(local.node_group_user_data, name, "")
      
      # Ensure metadata service is correctly configured
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }] : []
  }
}

# No longer creating custom launch templates here
# Instead, we're letting the EKS module create them with proper permissions
# This should fix the "You are not authorized to launch instances with this launch template" error

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
  create_iam_role                 = var.create_cluster_iam_role
  iam_role_arn                    = var.create_cluster_iam_role ? null : var.cluster_iam_role_arn
  
  # Always create security group
  create_node_security_group      = true
  
  # Configure node groups with minimal defaults
  # Most configuration is now done in the eks_managed_node_group_configs local
  eks_managed_node_group_defaults = {
    # Fix for iam_role_additional_policies type mismatch
    # Use a list of policy ARNs to ensure consistent type with upstream module
    iam_role_additional_policies = {
      # Empty map to ensure consistent type with expected input
    }
  }
  
  # Use our prepared node group configurations with launch templates
  eks_managed_node_groups = {
    for name, config in local.eks_managed_node_group_configs : name => merge(
      config,
      {
        # Add the launch template configurations if they exist
        launch_template_configs = lookup(local.eks_managed_node_group_launch_templates, name, [])
      }
    )
  }

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