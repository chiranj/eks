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

  # CUSTOM LAUNCH TEMPLATES restored from rollback point
  # Generate user-data for custom AMI bootstrapping
  # This will be a dependency loop that can only be resolved at apply time
  # We can use a null resource to defer the creation of user data until eks module outputs are available
  user_data_template = {
    for name, group in var.eks_managed_node_groups : name => {
      cluster_name         = local.name
      dns_cluster_ip       = local.dns_cluster_ip
      bootstrap_extra_args = lookup(group, "bootstrap_extra_args", "")
      kubelet_extra_args   = lookup(group, "kubelet_extra_args", "")
    }
  }

  # Custom Launch Template Configuration
  custom_launch_templates = {
    for name, group in var.eks_managed_node_groups : name => {
      # Use existing launch template if specified, otherwise create a new one
      create_launch_template = !var.use_existing_launch_templates || !contains(keys(local.launch_template_data), name)

      # Launch template name from existing template or create a new one
      name = var.use_existing_launch_templates && contains(keys(local.launch_template_data), name) ? local.launch_template_data[name].name : null
      id   = var.use_existing_launch_templates && contains(keys(local.launch_template_data), name) ? local.launch_template_data[name].id : null

      # Custom AMI settings
      ami_id = lookup(group, "ami_id", "")

      # NOTE: IMPORTANT - This creates a dependency cycle when trying to apply everything at once
      # To properly deploy with custom AMIs, use a multi-phase deployment:
      #
      # Phase 1: Deploy control plane only
      #   terraform apply -target=module.eks_cluster.module.eks.aws_eks_cluster.this[0]
      #
      # Phase 2: Create launch template with complete data
      #   terraform apply -target=module.eks_cluster.module.eks.module.eks_managed_node_group[NODE_GROUP_NAME]
      #
      # Phase 3: Create node groups
      #   terraform apply -target=module.eks_cluster.module.eks.aws_eks_node_group.this[NODE_GROUP_NAME]
      #
      # Phase 4: Deploy everything else
      #   terraform apply
      #
      # This approach ensures proper node bootstrapping with all security data

      # We'll prioritize the complete bootstrap script whenever possible
      # This change addresses the empty user-data issue by forcing the use of the complete script
      # when using the deploy.sh phased deployment approach
      user_data = base64encode(
        templatefile("${path.module}/templates/user-data.sh", {
          cluster_name         = local.name
          cluster_endpoint     = try(module.eks.cluster_endpoint, "https://placeholder-endpoint-to-be-replaced.eks.amazonaws.com")
          cluster_ca_cert      = try(module.eks.cluster_certificate_authority_data, "UGxhY2Vob2xkZXIgQ0EgY2VydGlmaWNhdGUgdG8gYmUgcmVwbGFjZWQ=")
          dns_cluster_ip       = local.dns_cluster_ip
          bootstrap_extra_args = lookup(group, "bootstrap_extra_args", "")
          kubelet_extra_args   = lookup(group, "kubelet_extra_args", "")
          service_ipv4_cidr    = var.service_ipv4_cidr
          max_pods             = lookup(group, "max_pods", "110") # Default to 110 if not specified
        })
      )

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
      # Note: The format expected by newer EKS module versions is different
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

  # Configure managed node groups to use custom launch templates
  managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => {
      # Basic node group configuration
      name           = lookup(group, "name", name)
      min_size       = lookup(group, "min_size", 1)
      max_size       = lookup(group, "max_size", 3)
      desired_size   = lookup(group, "desired_size", 2)
      instance_types = lookup(group, "instance_types", ["t3.medium"])
      capacity_type  = lookup(group, "capacity_type", "ON_DEMAND")

      # Use custom launch template instead of allowing EKS to create one
      use_custom_launch_template = true
      launch_template_name       = var.use_existing_launch_templates && contains(keys(local.launch_template_data), name) ? local.launch_template_data[name].name : null
      launch_template_id         = var.use_existing_launch_templates && contains(keys(local.launch_template_data), name) ? local.launch_template_data[name].id : null

      # Custom launch template configuration
      launch_template_version = lookup(group, "launch_template_version", "$Latest")

      # Labels and tags
      labels = lookup(group, "labels", {})

      # Add required organizational tags
      tags = merge(
        lookup(group, "tags", {}),
        {
          # Required per organization policy "DenyWithNoCompTag"
          "ComponentID" = var.component_id
        }
      )

      # IAM role settings - use AWS managed policies for node groups
      create_iam_role = var.create_node_iam_role
      iam_role_arn    = var.create_node_iam_role ? null : var.node_iam_role_arn
    }
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
        # Embed the launch template configuration directly in each node group
        launch_template_name    = try(local.custom_launch_templates[name].name, null)
        launch_template_id      = try(local.custom_launch_templates[name].id, null)
        launch_template_version = try(local.custom_launch_templates[name].version, "$Latest")

        # When creating a new launch template
        create_launch_template      = try(local.custom_launch_templates[name].create_launch_template, true)
        launch_template_description = "Custom launch template for ${name} EKS managed node group"
        ami_id                      = try(local.custom_launch_templates[name].ami_id, "")
        user_data                   = try(local.custom_launch_templates[name].user_data, "")
        block_device_mappings       = try(local.custom_launch_templates[name].block_device_mappings, {})
        metadata_options            = try(local.custom_launch_templates[name].metadata_options, {})
        monitoring                  = try(local.custom_launch_templates[name].monitoring, {})
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