provider "aws" {
  region = "us-east-1"
}

locals {
  name   = "eks-cluster"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "eks-service-catalog"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

module "eks" {
  source = "../../"

  cluster_name    = local.name
  cluster_version = "1.29"

  # VPC Settings - using existing VPC from module 
  vpc_mode                       = "existing"
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  control_plane_subnet_ids       = module.vpc.intra_subnets
  cluster_endpoint_public_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    default = {
      name = "default-node-group"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 5
      desired_size = 2

      labels = {
        Environment = "dev"
        Role        = "general"
      }

      tags = local.tags
    },
    # Example of a node group with custom AMI
    custom-ami = {
      name = "custom-ami-node-group"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 1

      # Custom AMI ID - will use launch template with our fixed implementation
      ami_id = "ami-0123456789abcdef0"

      # Optional bootstrap arguments for the custom AMI
      bootstrap_extra_args = "--use-max-pods false"

      # Optional kubelet arguments
      kubelet_extra_args = "--node-labels=node.kubernetes.io/workload-type=cpu"

      labels = {
        Environment = "dev"
        Role        = "custom"
      }

      tags = local.tags
    }
  }

  # Enable add-ons
  enable_aws_load_balancer_controller = true

  # Node scaling method - use Karpenter instead of Cluster Autoscaler
  node_scaling_method = "karpenter"
  enable_keda         = true

  # Launch template configuration for custom AMI
  node_group_ami_id = var.node_group_ami_id

  enable_external_dns = false
  enable_prometheus   = false

  # GitLab integration
  trigger_gitlab_pipeline = true
  # Optional custom IAM role ARN for GitLab CI/CD deployment
  gitlab_aws_role_arn = var.gitlab_aws_role_arn

  tags = local.tags
}