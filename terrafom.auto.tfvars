# Cluster configuration
region         = "us-east-1"
cluster_name   = "eks132-lt-dev"
cluster_version = "1.32"

# VPC configuration (use existing VPC)
vpc_mode      = "existing"
vpc_id        = "vpc-"
subnet_ids    = ["subnet-", "subnet-"]
#control_plane_subnet_ids = ["subnet-", "subnet-"]

# IAM role configuration
create_cluster_iam_role = false
create_addon_roles = true
cluster_iam_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
create_node_iam_role = false
node_iam_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
iam_admin_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"

# Cluster networking configuration
service_ipv4_cidr = "172.20.0.0/16"
cluster_ip_family = "ipv4"

# Node group configuration
eks_managed_node_groups = {
  default = {
    name = "eks132-dev-ng"
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    min_size     = 2
    max_size     = 5
    desired_size = 2
    labels = {
      Environment = "dev"
      Role        = "general"
    }
    ami_id = "ami-03bc4bb1e"
    max_pods = "70"
    update_config = {
      max_unavailable = 1
    }
  }
}

# Access configuration - new in EKS module v20
eks_access_entries = {
  admin-role = {
    principal_arn = "arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f"
    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

# Add-ons configuration
enable_aws_load_balancer_controller = true
node_scaling_method                 = "karpenter"  # "karpenter", "cluster_-autoscaler", or "none"
enable_keda                         = true
enable_external_dns                 = true
enable_prometheus                   = true
enable_secrets_manager              = true
enable_cert_manager                 = true
enable_nginx_ingress                = true
enable_adot                         = true
enable_fluent_bit                   = true

# Storage CSI Drivers - as EKS managed add-ons
enable_ebs_csi_driver               = true
enable_efs_csi_driver               = true

# External DNS configuration
external_dns_hosted_zone_source     = "existing"
external_dns_existing_hosted_zone_id = "Z0065550"

# GitLab integration
trigger_gitlab_pipeline   = false

# Organization policy required tag
component_id = 14800

# Tags
tags = {
  Environment = "dev"
  ManagedBy   = "terraform"
  Project     = "eks-cluster"
}
