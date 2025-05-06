/**
 * # EKS Cluster Module
 * 
 * This module creates an Amazon EKS cluster with node groups.
 */

locals {
  name = var.cluster_name

  # DNS cluster IP based on service CIDR
  dns_cluster_ip = cidrhost(var.service_ipv4_cidr, 10)

  # First identify which node groups have custom AMIs
  node_groups_with_custom_ami = {
    for name, group in var.eks_managed_node_groups :
    name => group if lookup(group, "ami_id", "") != ""
  }
  
  # Extract launch template details from ARNs for pre-created templates
  launch_template_data = {
    for name, arn in var.launch_template_arns : name => {
      # ARN format: arn:aws:ec2:region:account-id:launch-template/lt-id
      name = reverse(split("/", arn))[0]
      id   = reverse(split("/", arn))[0]
    } if contains(keys(var.eks_managed_node_groups), name)
  }

  # Prepare node groups configuration based on whether we're using launch templates
  # This handles conditional type safety by consistently preparing node group configs
  eks_managed_node_group_configs = {
    for name, group in var.eks_managed_node_groups : name => merge(
      # Base configuration that always applies
      {
        for k, v in group : k => v if k != "ami_id"
      },

      # OPTION 1: Use pre-created launch templates if specified
      var.use_existing_launch_templates && contains(keys(var.launch_template_arns), name) ? {
        # Use existing launch template ID
        launch_template_id      = lookup(local.launch_template_data, name, {}).id
        create_launch_template  = false
      } : 
      # OPTION 2: Create launch templates for node groups with custom AMIs
      var.create_launch_templates_for_custom_amis && lookup(group, "ami_id", "") != "" ? {
        # Connect to the launch template we'll create
        launch_template_name    = aws_launch_template.custom_ami[name].name
        launch_template_version = aws_launch_template.custom_ami[name].latest_version
      } : {},
      
      # If using pre-created IAM role, ensure we pass through the IAM role config
      # This allows the eks_managed_node_group_defaults to take effect
      !var.create_node_iam_role ? {
        # We do not override these here since eks_managed_node_group_defaults will handle it
        # Any explicit IAM role settings would be added here if needed
      } : {}
    )
  }
}

# Create launch templates for node groups with custom AMIs
# Only create if:
# 1. We're supposed to create launch templates for custom AMIs
# 2. We're not using existing launch templates
# 3. The node group has a custom AMI
resource "aws_launch_template" "custom_ami" {
  for_each = var.create_launch_templates_for_custom_amis && !var.use_existing_launch_templates ? local.node_groups_with_custom_ami : {}

  name_prefix = "${local.name}-${each.key}-"
  image_id    = each.value.ami_id

  # Use instance type from node group if specified
  instance_type = lookup(each.value, "instance_types", null) != null ? lookup(each.value, "instance_types", [])[0] : null

  # Critical: Public launch template that allows EKS to use it without permission issues
  tag_specifications {
    resource_type = "launch-template"
    tags = merge(
      var.tags,
      {
        Name = "${local.name}-${each.key}-launch-template"
        "kubernetes.io/cluster/${local.name}" = "owned"
      }
    )
  }

  # Only add user_data after the cluster exists to get the correct endpoint
  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    cluster_name               = local.name
    cluster_endpoint           = module.eks.cluster_endpoint
    certificate_authority_data = module.eks.cluster_certificate_authority_data
    service_ipv4_cidr          = var.service_ipv4_cidr
    dns_cluster_ip             = local.dns_cluster_ip
    bootstrap_extra_args       = lookup(each.value, "bootstrap_extra_args", "")
    kubelet_extra_args         = lookup(each.value, "kubelet_extra_args", "")
    extra_kubelet_args         = lookup(each.value, "kubelet_extra_args", "") # Duplicate for compatibility with template
  }))

  # Add tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${local.name}-${each.key}-node"
        "kubernetes.io/cluster/${local.name}" = "owned"
      }
    )
  }

  # Add tags for EBS volumes created by the node
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${local.name}-${each.key}-volume"
        "kubernetes.io/cluster/${local.name}" = "owned"
      }
    )
  }

  # Add network interface tags
  tag_specifications {
    resource_type = "network-interface"
    tags = merge(
      var.tags,
      {
        Name = "${local.name}-${each.key}-eni"
        "kubernetes.io/cluster/${local.name}" = "owned"
      }
    )
  }

  # Make the template available to EKS service
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }
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
  create_iam_role                 = var.create_cluster_iam_role
  iam_role_arn                    = var.create_cluster_iam_role ? null : var.cluster_iam_role_arn
  
  # Always create security group
  create_node_security_group      = true
  
  # Configure node groups to use existing IAM role if specified
  eks_managed_node_group_defaults = merge(
    var.create_node_iam_role ? {} : {
      create_iam_role = false
      iam_role_arn    = var.node_iam_role_arn
    },
    {
      # Fix for iam_role_additional_policies type mismatch
      iam_role_additional_policies = {},
      
      # Ensure EKS has permission to use launch templates and AMIs
      ami_type = "CUSTOM",  # This tells EKS we're using custom AMIs
      
      # Add block device mappings to handle AMI permissions
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 20
            volume_type = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  )
  
  # Use the prepared node group configs with proper launch template handling
  eks_managed_node_groups = local.eks_managed_node_group_configs

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