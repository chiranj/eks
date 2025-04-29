/**
 * # EKS Cluster Module
 * 
 * This module creates an Amazon EKS cluster with node groups.
 */

locals {
  name = var.cluster_name
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

  # EKS Managed Node Group(s)
  eks_managed_node_groups = var.eks_managed_node_groups

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