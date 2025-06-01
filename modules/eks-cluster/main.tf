/**
 * # EKS Cluster Module
 * 
 * This module creates an Amazon EKS cluster with node groups that use custom launch templates.
 */

# Fetch VPC details to get CIDR automatically
data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  name = var.cluster_name

  # DNS cluster IP based on service CIDR
  dns_cluster_ip = cidrhost(var.service_ipv4_cidr, 10)

  # Check if we should use custom launch templates from outside the module
  use_existing_launch_templates = var.use_existing_launch_templates

  # Default tags for resources
  default_tags = merge(
    var.tags,
    {
      "ClusterName" = local.name
      "ManagedBy"   = "terraform"
    },
    var.component_id != "" ? { "ComponentID" = var.component_id } : {}
  )

  # Configure managed node groups with sensible defaults
  managed_node_groups = {
    for name, group in var.eks_managed_node_groups : name => merge(
      {
        # Basic node group configuration with defaults 
        name           = name
        min_size       = 1
        max_size       = 3
        desired_size   = 2
        instance_types = ["t3.medium"]
        capacity_type  = "ON_DEMAND"

        # IAM role settings - use AWS managed policies for node groups
        create_iam_role = var.create_node_iam_role
        iam_role_arn    = var.create_node_iam_role ? null : var.node_iam_role_arn

        # Always use custom launch template
        use_custom_launch_template = true
      },
      group # Override with provided values from var.eks_managed_node_groups
    )
  }
}

# Create custom launch templates only when not using existing ones
resource "aws_launch_template" "node_group_launch_template" {
  # Only create launch templates if we're not using existing ones
  count = local.use_existing_launch_templates ? 0 : 1

  # Use a single launch template for all node groups
  name                   = "${local.name}-eks-node-template"
  description            = "Custom launch template for EKS managed node groups"
  update_default_version = true

  # Use the node_group_ami_id if specified, otherwise EKS selects the appropriate AMI
  image_id = var.node_group_ami_id != "" ? var.node_group_ami_id : null

  # User data to properly bootstrap nodes to the cluster
  # Note: The EKS module will update this template with proper values at runtime
  # First phase bootstrap with placeholders; EKS module will complete the actual bootstrap
  user_data = base64encode(templatefile("${path.module}/templates/user-data.tpl", {
    cluster_name         = local.name
    cluster_endpoint     = "placeholder-for-cluster-endpoint"
    cluster_ca_cert      = "placeholder-for-cluster-ca"
    dns_cluster_ip       = local.dns_cluster_ip
    service_ipv4_cidr    = var.service_ipv4_cidr
    kubelet_extra_args   = ""
    bootstrap_extra_args = "--use-max-pods false"
    max_pods             = "110"
  }))

  # Security groups will be assigned by the EKS module when it creates the node group

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 150
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Security hardening for EC2 metadata service
  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required" # IMDSv2 required for security
  }

  # Enable detailed monitoring for better metrics
  monitoring {
    enabled = true
  }

  # Define tags for the launch template
  tags = merge(
    local.default_tags,
    {
      Name = "${local.name}-eks-node-template"
    }
  )

  # Tag resources created from this launch template
  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])
    content {
      resource_type = tag_specifications.value
      tags = merge(
        local.default_tags,
        {
          Name                                  = "${local.name}-${tag_specifications.value}"
          "kubernetes.io/cluster/${local.name}" = "owned"
        }
      )
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Basic cluster configuration
  cluster_name                    = local.name
  cluster_version                 = var.cluster_version
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  control_plane_subnet_ids        = var.control_plane_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_ip_family               = var.cluster_ip_family
  cluster_service_ipv4_cidr       = var.service_ipv4_cidr

  # IAM role configuration for cluster
  create_iam_role = var.create_cluster_iam_role
  iam_role_arn    = var.create_cluster_iam_role ? null : var.cluster_iam_role_arn

  # Add only non-default IAM policies - the following policies are already attached by default:
  # - AmazonEKSWorkerNodePolicy
  # - AmazonEC2ContainerRegistryReadOnly
  # - AmazonEKS_CNI_Policy
  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Custom security group names for better identification
  cluster_security_group_name = "${local.name}-cluster-sg"
  node_security_group_name    = "${local.name}-node-sg"

  # Add VPC CIDR to the cluster security group for kubectl access
  cluster_security_group_additional_rules = {
    vpc_cidr_access = {
      description       = "Allow pods to communicate with the cluster API Server"
      protocol          = "tcp"
      from_port         = 443
      to_port           = 443
      type              = "ingress"
      cidr_blocks       = [data.aws_vpc.selected.cidr_block]
    }
  }
  
  # Managed node group defaults
  eks_managed_node_group_defaults = {
    # Apply consistent tagging to all node group resources
    tags = merge(
      {
        "ManagedBy" = "terraform"
      },
      var.component_id != "" ? { "ComponentID" = var.component_id } : {}
    )

    # Always use custom launch templates
    use_custom_launch_template = true

    # Don't create launch templates in the EKS module, we manage them ourselves
    create_launch_template = false
  }

  # Managed node groups configuration with launch templates
  eks_managed_node_groups = {
    for name, group in local.managed_node_groups : name => merge(
      group,
      # Configure launch template based on whether using external templates or our own
      local.use_existing_launch_templates ?
      {
        # Use existing launch templates provided in variables
        launch_template_id      = lookup(var.launch_template_ids, name, null)
        launch_template_version = lookup(var.launch_template_versions, name, "$Latest")
      } :
      {
        # Use our shared custom launch template
        launch_template_id      = aws_launch_template.node_group_launch_template[0].id
        launch_template_version = aws_launch_template.node_group_launch_template[0].latest_version
      }
    )
  }

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

  # Cluster addons with conditional configuration based on feature flags
  cluster_addons = {
    # Core addons - always enabled
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }

    # Core add-ons - always enabled
    #aws-ebs-csi-driver = {
    #  most_recent              = true
    #  service_account_role_arn = var.ebs_csi_driver_role_arn != "" ? var.ebs_csi_driver_role_arn : null
    #}

    #aws-efs-csi-driver = {
    #  most_recent              = true
    #  service_account_role_arn = var.efs_csi_driver_role_arn != "" ? var.efs_csi_driver_role_arn : null
    #}

    #external-dns = {
    #  most_recent              = true
    #  service_account_role_arn = var.external_dns_role_arn != "" ? var.external_dns_role_arn : null
    #}

    #cert-manager = {
    #  most_recent              = true
    #  service_account_role_arn = var.cert_manager_role_arn != "" ? var.cert_manager_role_arn : null
    #}
  }

  # Enable IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Apply consistent tags
  tags = var.tags

  # Ensure launch template exists before EKS cluster
  depends_on = [
    aws_launch_template.node_group_launch_template
  ]
}
