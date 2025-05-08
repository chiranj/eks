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

  # REMOVED: Old user_data_template definition that's no longer used
  # We're now using enable_bootstrap_user_data with pre_bootstrap_user_data in the eks_managed_node_groups section

  # NOTE: We're no longer using custom_launch_templates.
  # Instead, we'll define all launch template settings directly in eks_managed_node_groups
  # This is the newer approach recommended for EKS module v20+
  
  # We keep the custom_launch_templates local as a reference for some config settings
  custom_launch_templates = {
    for name, group in var.eks_managed_node_groups : name => {
      # Block device mappings for the launch template
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = lookup(group, "disk_size", 100)
            volume_type           = "gp3" # Required: Must use gp3 instead of gp2
            iops                  = 3000
            throughput            = 150
            encrypted             = true # Required: Must be encrypted
            delete_on_termination = true
          }
        }
      }

      # Required monitoring 
      monitoring = {
        enabled = true
      }

      # Required metadata settings
      metadata_options = {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = 2
        http_tokens                 = "required"
      }

      # Using tag specifications for resources
      tags = merge(
        lookup(group, "tags", {}),
        {
          Name        = lookup(group, "name", name)
          ClusterName = local.name
          ManagedBy   = "terraform"
        },
        var.component_id != "" ? { ComponentID = var.component_id } : {}
      )
    }
  }

  # Configure managed node groups using the example approach
  managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => merge(
      group,
      {
        # Basic node group configuration 
        name           = lookup(group, "name", name)
        min_size       = lookup(group, "min_size", 1)
        max_size       = lookup(group, "max_size", 3)
        desired_size   = lookup(group, "desired_size", 2)
        instance_types = lookup(group, "instance_types", ["t3.medium"])
        capacity_type  = lookup(group, "capacity_type", "ON_DEMAND")

        # Force creation of a new launch template by not using existing ones
        launch_template_name    = null
        launch_template_id      = null
        launch_template_version = "$Latest"

        # Have the module create and manage the launch template
        create_launch_template      = true
        launch_template_description = "Custom launch template for ${name} EKS managed node group ${timestamp()}"
        
        # Specify AMI ID directly (from node group config)
        ami_id = lookup(group, "ami_id", "")
        
        # Enable the module's bootstrap user data generation
        enable_bootstrap_user_data = true
        
        # Add custom script before the main bootstrap
        pre_bootstrap_user_data = <<-EOT
          #!/bin/bash
          set -ex
          
          # Basic system configuration
          swapoff -a
          set -o xtrace
          
          # Enable IP forwarding for Kubernetes networking
          echo 1 > /proc/sys/net/ipv4/ip_forward
          echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
          sysctl -p
          
          # Configure kernel parameters for Kubernetes
          cat <<EOF > /etc/sysctl.d/99-kubernetes.conf
          net.ipv4.tcp_keepalive_time = 600
          net.ipv4.tcp_keepalive_intvl = 30
          net.ipv4.tcp_keepalive_probes = 10
          net.ipv4.ip_local_port_range = 1024 65000
          net.ipv4.tcp_tw_reuse = 1
          fs.file-max = 2097152
          fs.inotify.max_user_watches = 524288
          vm.max_map_count = 262144
          EOF
          sysctl --system
          
          # Log bootstrap process starting
          echo "Node pre-bootstrap configuration complete"
        EOT
        
        # Add bootstrap extra args for kubelet configuration
        bootstrap_extra_args = "--use-max-pods false --kubelet-extra-args '--max-pods=${lookup(group, "max_pods", "70")}'"

        # Use custom launch template configs from our local
        block_device_mappings = try(local.custom_launch_templates[name].block_device_mappings, {})
        metadata_options      = try(local.custom_launch_templates[name].metadata_options, {})
        monitoring            = try(local.custom_launch_templates[name].monitoring, {})
        
        # The EKS module expects a list of resource types as strings
        tag_specifications = ["instance", "volume", "network-interface"]

        # Labels for node groups
        labels = lookup(group, "labels", {})

        # Add all necessary tags directly to the node group's tags
        tags = merge(
          lookup(group, "tags", {}),
          {
            "Name"        = lookup(group, "name", name)
            "ClusterName" = local.name
            "ManagedBy"   = "terraform"
            "ComponentID" = var.component_id
          }
        )

        # IAM role settings - use AWS managed policies for node groups
        create_iam_role = var.create_node_iam_role
        iam_role_arn    = var.create_node_iam_role ? null : var.node_iam_role_arn
      }
    )
  }
}

# Restore custom IAM policy for launch template management
resource "aws_iam_policy" "launch_template_access" {
  name        = "${local.name}-ec2-full-access"
  description = "Provides all necessary EC2 permissions for EKS node groups with custom AMIs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:ModifyLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages"
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

  # =================================================================
  # RESTORED: Using custom launch templates for node groups
  # =================================================================

  # Add custom EC2 permissions policy for launch template management
  iam_role_additional_policies = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    EC2FullAccess                      = aws_iam_policy.launch_template_access.arn
  }

  # Standard EKS cluster settings
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 90
  cluster_enabled_log_types              = ["api", "audit", "authenticator"]
  cluster_security_group_name            = "${local.name}-cluster-sg"
  node_security_group_name               = "${local.name}-node-sg"

  # Organizational tagging requirements
  eks_managed_node_group_defaults = {
    # Ensure tags are added to all resources created for node groups
    # This addresses the organization policy "DenyWithNoCompTag"
    tags = merge(
      {
        "ManagedBy" = "terraform"
      },
      var.component_id != "" ? { "ComponentID" = var.component_id } : {}
    )

    # All node groups will use custom launch templates
    use_custom_launch_template = true
  }

  # Managed node groups with custom launch templates inside each node group
  eks_managed_node_groups = {
    for name, group in local.managed_node_groups : name => merge(
      group,
      {
        # FORCE RECREATION: Set these to null to force creation of a new template
        # This is the key to ensuring our user_data gets applied
        launch_template_name    = null
        launch_template_id      = null
        launch_template_version = "$Latest"

        # Always create a new launch template with our custom user data
        create_launch_template      = true
        launch_template_description = "Custom launch template for ${name} EKS managed node group ${timestamp()}"
        # Set AMI ID directly here instead of getting it from custom_launch_templates
        ami_id = lookup(group, "ami_id", "")

        # NEW APPROACH: Using the module's bootstrap user data mechanism
        # This enables the module to generate the correct bootstrap script

        # Enable the module's bootstrap user data generation
        enable_bootstrap_user_data = true

        # Add custom script before the main bootstrap
        pre_bootstrap_user_data = <<-EOT
          #!/bin/bash
          set -ex
          
          # Basic system configuration
          swapoff -a
          set -o xtrace
          
          # Enable IP forwarding for Kubernetes networking
          echo 1 > /proc/sys/net/ipv4/ip_forward
          echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
          sysctl -p
          
          # Configure kernel parameters for Kubernetes
          cat <<EOF > /etc/sysctl.d/99-kubernetes.conf
          net.ipv4.tcp_keepalive_time = 600
          net.ipv4.tcp_keepalive_intvl = 30
          net.ipv4.tcp_keepalive_probes = 10
          net.ipv4.ip_local_port_range = 1024 65000
          net.ipv4.tcp_tw_reuse = 1
          fs.file-max = 2097152
          fs.inotify.max_user_watches = 524288
          vm.max_map_count = 262144
          EOF
          sysctl --system
          
          # Log bootstrap process starting
          echo "Node pre-bootstrap configuration complete"
        EOT

        # Add bootstrap extra args for kubelet configuration
        bootstrap_extra_args = "--use-max-pods false --kubelet-extra-args '--max-pods=${lookup(group, "max_pods", "70")}'"

        block_device_mappings = try(local.custom_launch_templates[name].block_device_mappings, {})
        metadata_options      = try(local.custom_launch_templates[name].metadata_options, {})
        monitoring            = try(local.custom_launch_templates[name].monitoring, {})
        # The EKS module expects a list of resource types as strings
        tag_specifications = ["instance", "volume", "network-interface"]

        # Add all necessary tags directly to the node group's tags
        tags = merge(
          lookup(group, "tags", {}),
          {
            "Name"        = lookup(group, "name", name)
            "ClusterName" = local.name
            "ManagedBy"   = "terraform"
          },
          var.component_id != "" ? { "ComponentID" = var.component_id } : {}
        )
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
    # Add EBS CSI driver as a managed add-on if enabled
    aws-ebs-csi-driver = var.enable_ebs_csi_driver ? {
      most_recent              = true
      service_account_role_arn = var.ebs_csi_driver_role_arn
    } : null

    # Add EFS CSI driver as a managed add-on if enabled
    aws-efs-csi-driver = var.enable_efs_csi_driver ? {
      most_recent              = true
      service_account_role_arn = var.efs_csi_driver_role_arn
    } : null
  }

  # Enable OIDC provider for IAM Roles for Service Accounts (IRSA)
  # This creates an IAM OIDC provider for the cluster
  # The root module uses this OIDC provider for all add-on IAM roles
  enable_irsa = true

  tags = var.tags
}