
module "eks-managed-node" {
  depends_on = [aws_launch_template.node_group_launch_template]
  source     = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version    = "~> 20.0"

  cluster_name    = module.eks_cluster.cluster_name
  cluster_version = "1.32"
  # need this otherwise can't access EKS from outside VPC. Ref: https://github.com/terraform-aws-modules/terraform-aws-eks#input_cluster_endpoint_public_access
  # add other IAM users who can access a K8s cluster (by default, the IAM user who created a cluster is given access already)
  #aws_auth_users = []
  # Cluster Addon as failed without them
  create_iam_role = false
  #create_node_iam_role = false
  #create_cloudwatch_log_group = false

  # EKS Addons
  #cluster_addons = {
  #  coredns                = {}
  #  eks-pod-identity-agent = {}
  #  kube-proxy             = {}
  #  vpc-cni                = {}
  #}

  #vpc_id     = "vpc-0fdf8f6123bcee653"
  subnet_ids                 = ["subnet-06fbd21c8b18472d5", "subnet-00ec24404cb22eef3"]
  iam_role_arn               = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
  tags                       = module.common-tags.tags
  name                       = "psbnode-group-lab-1"
  cluster_auth_base64        = module.eks_cluster.cluster_certificate_authority_data
  cluster_endpoint           = module.eks_cluster.cluster_endpoint
  ami_type                   = "CUSTOM"
  cluster_service_cidr       = "100.64.0.0/16"
  instance_types             = ["t3a.medium"] # since we are using AWS-VPC-CNI, allocatable pod IPs are defined by instance size: https://docs.google.com/spreadsheets/d/1MCdsmN7fWbebscGizcK6dAaPGS-8T_dYxWp0IdwkMKI/edit#gid=1549051942, https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt
  ami_id                     = "ami-03b4e6bf3aec4bb1e"
  disk_size                  = 100
  enable_bootstrap_user_data = true
  user_data_template_path    = "linux_user_data.tpl"
  create_launch_template     = false
  use_custom_launch_template = true
  launch_template_id         = aws_launch_template.node_group_launch_template.id
  launch_template_version    = aws_launch_template.node_group_launch_template.latest_version
  ebs_optimized              = true
  enable_monitoring          = true

} // NodeCreation



resource "aws_launch_template" "node_group_launch_template" {
  name                   = "PAAS-Launch-Template"
  description            = " PAAS Launch Template"
  update_default_version = true
  image_id               = "ami-03b4e6bf3aec4bb1e"
  #instance_type = "t3.medium"
  key_name = "psb-lab-dev-key-pair-1"
  user_data = base64encode(templatefile("linux_user_data.tpl", {
    cluster_name         = module.eks_cluster.cluster_name,
    cluster_endpoint     = module.eks_cluster.cluster_endpoint,
    cluster_auth_base64  = module.eks_cluster.cluster_certificate_authority_data,
    cluster_service_cidr = "100.64.0.0/16"
    region               = "us-east-1"
  }))
  vpc_security_group_ids = [module.ssh_sg.security_group_id]

  //volume_tags   = module.common-tags.tags
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = "100"
      delete_on_termination = true
      volume_type           = "gp3"
      encrypted             = true

    }
  }
  tags = merge(
    module.common-tags.tags,
    {
      "efs.csi.aws.com/cluster"                               = "true",
      "k8s.io/cluster-autoscaler/enabled"                     = "true",
      "k8s_namespace"                                         = "lab",
      "kubernetes.io/cluster/module.eks_cluster.cluster_name" = "owned",
      "k8s_namespace"                                         = "lab"
    }
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                                    = "test"
      ComponentID                                             = "14800"
      "kubernetes.io/cluster/module.eks_cluster.cluster_name" = "owned",
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name                                                    = "test"
      ComponentID                                             = "14800"
      "kubernetes.io/cluster/module.eks_cluster.cluster_name" = "owned",
    }
  }
}
