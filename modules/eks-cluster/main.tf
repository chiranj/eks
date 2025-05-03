/**
 * # EKS Cluster Module
 * 
 * This module creates an Amazon EKS cluster with node groups.
 */

locals {
  name = var.cluster_name

  # DNS cluster IP based on service CIDR
  dns_cluster_ip = cidrhost(var.service_ipv4_cidr, 10)

  # Identify node groups that need custom AMIs via launch templates
  node_groups_with_custom_ami = {
    for name, group in var.eks_managed_node_groups :
    name => group if lookup(group, "ami_id", "") != ""
  }

  # Create node groups without launch templates (default EKS AMI)
  node_groups_without_custom_ami = {
    for name, group in var.eks_managed_node_groups :
    name => {
      for k, v in group : k => v if k != "ami_id"
    } if lookup(group, "ami_id", "") == ""
  }

  # Final node groups map - replaces ami_id with launch_template for groups with custom AMI
  eks_managed_node_groups = var.create_launch_templates_for_custom_amis ? merge(
    local.node_groups_without_custom_ami,
    {
      for name, group in local.node_groups_with_custom_ami : name => merge(
        {
          for k, v in group : k => v if k != "ami_id"
        },
        {
          launch_template_id      = aws_launch_template.custom_ami[name].id
          launch_template_version = aws_launch_template.custom_ami[name].latest_version
        }
      )
    }
  ) : var.eks_managed_node_groups
}

# Create launch templates for node groups with custom AMIs
resource "aws_launch_template" "custom_ami" {
  for_each = var.create_launch_templates_for_custom_amis ? local.node_groups_with_custom_ami : {}

  name_prefix = "${local.name}-${each.key}-"
  image_id    = each.value.ami_id

  # Use instance type from node group if specified
  instance_type = lookup(each.value, "instance_types", null) != null ? lookup(each.value, "instance_types", [])[0] : null

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
      }
    )
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

  # EKS Managed Node Group(s) - Using our processed node groups
  eks_managed_node_groups = local.eks_managed_node_groups

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