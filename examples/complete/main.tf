terraform {
  backend "s3" {
    bucket = "psb-terraform-state-bucket"
    key    = "ekscluster_managednodegroup_awstroubleshooting.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock-dynamo"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


module "eks_cluster" {
  #depends_on = [aws_launch_template.node_group_launch_template]
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "eks-paas-cluster-aws"
  cluster_version = "1.32"
  cluster_endpoint_public_access = true # need this otherwise can't access EKS from outside VPC. Ref: https://github.com/terraform-aws-modules/terraform-aws-eks#input_cluster_endpoint_public_access
  # add other IAM users who can access a K8s cluster (by default, the IAM user who created a cluster is given access already)
  #aws_auth_users = []
  # Cluster Addon as failed without them

  create_iam_role = false
  create_node_iam_role = false
  create_cloudwatch_log_group = false
  cluster_encryption_config = {} 
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
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  # EKS Addons
  #cluster_addons = {
  #  coredns                = {}
  #  eks-pod-identity-agent = {}
  #  kube-proxy             = {}
  #  vpc-cni                = {}
  #}

  vpc_id     = "vpc-0fdf8f6123bcee653"
  subnet_ids = ["subnet-06fbd21c8b18472d5", "subnet-00ec24404cb22eef3"]
  iam_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
  #iam_role_arn = "arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f"
  tags              = module.common-tags.tags
  #iam_instance_profile_arn = "arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f"
  #service_account_role_arn = "arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f"


} // Control Plane Creation

module "ssh_sg"{
   source      = "git::https://prod-cicm.uspto.gov/gitlab/psb/terraform.git//aws-modules/security-group"
   name        = "eksnode-sg"
   description = "Security group with ports open for tomcat"
   vpc_id      = "vpc-0fdf8f6123bcee653"
   #Add TOMCAT  rules
   ingress_rules = ["ssh-tcp"]
   egress_rules = ["all-all"]
   ingress_cidr_blocks      = ["10.0.0.0/8"]
   ingress_ipv6_cidr_blocks = [] # Not all VPCs have IPv6 enabled, but if you have it enabled, then this will work - ["${data.aws_vpc.default.ipv6_cidr_block}"]
   tags        = module.common-tags.tags

}




# Attaching UACS tags
module "common-tags" {
    source = "git::https://prod-cicm.uspto.gov/gitlab/psb/terraform.git//aws-modules/UACS-TAGS"

    BusinessArea           = "Infra"
    Name                   = "EKSCluster"
    Stack                  = "PAAS"
    PPAProgramCode         = "SPAAS0"
    CommitId               = "775d7a0d3f1ad7edc489a7ea78854a8c5f39344e"
    LastUpdateBy           = "schennu"
    BusinessProduct        = "InfraTest"
    LastUpdate             = "Today"
    ProductLine            = "EBPL"
    ComponentID            = "14800"
    KeepOn                 = "Mo+Tu+We+Th+Fr:08-18/Sa:00-23/Su:00-23"
    Environment            = "DEV"
    Product                = "PaaS"
}


output "cluster_arn" {
    value   = module.eks_cluster.cluster_arn

}

output "cluster_certificate_authority_data" {
    value = module.eks_cluster.cluster_certificate_authority_data
}


output "cluster_endpoint" {
  value       = module.eks_cluster.cluster_endpoint 

}

output "cluster_id" {
  value       = module.eks_cluster.cluster_id 
}


output "cluster_name" {
  value       = module.eks_cluster.cluster_name 

}
