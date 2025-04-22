/**
 * # EKS Cluster with Add-ons
 *
 * This Terraform configuration creates an EKS cluster with optional add-ons.
 * It is designed to be deployed through AWS Service Catalog using the Terraform Reference Engine.
 */

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "eks_cluster_module" {
  source = "../"
  
  # Cluster configuration
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  region          = var.region
  
  # VPC configuration based on selection
  vpc_mode              = var.vpc_mode
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids
  vpc_cidr              = var.vpc_cidr
  azs                   = ["${var.region}a", "${var.region}b", "${var.region}c"]
  
  # Cluster endpoint access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access == "true" ? true : false
  cluster_endpoint_private_access = var.cluster_endpoint_private_access == "true" ? true : false
  
  # Node groups
  eks_managed_node_groups = {
    default = {
      name = var.node_group_name

      instance_types = [var.node_group_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_capacity

      labels = {
        Environment = "prod"
        Role        = "general"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled" = var.node_scaling_method == "cluster_autoscaler" ? "true" : "false"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = var.node_scaling_method == "cluster_autoscaler" ? "owned" : "false"
      }
    }
  }
  
  # Add-ons configuration
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller == "true" ? true : false
  node_scaling_method                 = var.node_scaling_method
  enable_keda                         = var.enable_keda == "true" ? true : false
  enable_external_dns                 = var.enable_external_dns == "true" ? true : false
  external_dns_hosted_zone_source     = var.external_dns_hosted_zone_source
  external_dns_existing_hosted_zone_id = var.external_dns_existing_hosted_zone_id
  external_dns_domain                 = var.external_dns_domain
  enable_prometheus                   = var.enable_prometheus == "true" ? true : false
  enable_secrets_manager              = var.enable_secrets_manager == "true" ? true : false
  enable_cert_manager                 = var.enable_cert_manager == "true" ? true : false
  enable_nginx_ingress                = var.enable_nginx_ingress == "true" ? true : false
  enable_adot                         = var.enable_adot == "true" ? true : false
  enable_fluent_bit                   = var.enable_fluent_bit == "true" ? true : false
  
  # GitLab integration
  trigger_gitlab_pipeline = var.trigger_gitlab_pipeline == "true" ? true : false
  gitlab_token           = var.gitlab_token
  gitlab_project_id      = var.gitlab_project_id
  gitlab_pipeline_ref    = var.gitlab_pipeline_ref
  
  # Default tags
  tags = {
    Environment = "Production"
    Provisioner = "ServiceCatalog-Terraform"
    ClusterName = var.cluster_name
  }
}