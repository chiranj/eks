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
  version = "~> 19.0"

  cluster_name                    = local.name
  cluster_version                 = var.cluster_version
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  control_plane_subnet_ids        = var.control_plane_subnet_ids
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # EKS Managed Node Group(s)
  eks_managed_node_groups = var.eks_managed_node_groups

  # aws-auth ConfigMap
  manage_aws_auth_configmap = var.manage_aws_auth_configmap
  aws_auth_roles            = var.aws_auth_roles
  aws_auth_users            = var.aws_auth_users

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