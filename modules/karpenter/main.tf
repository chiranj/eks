/**
 * # Karpenter Module
 *
 * This module creates the necessary resources for the Karpenter add-on including
 * IAM roles, SQS queue, EventBridge rules, and instance profile.
 */

# Extract role name from ARN if specified
locals {
  has_node_iam_role_arn = var.node_iam_role_arn != ""
  node_role_name        = local.has_node_iam_role_arn ? reverse(split("/", var.node_iam_role_arn))[0] : ""
}

# Create the AWS Spot Fleet service-linked role (only if using spot instances)
# This is disabled as we only use reserved instances per organizational policy
resource "aws_iam_service_linked_role" "spot" {
  count            = var.create_spot_service_linked_role ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
  description      = "Service-linked role for AWS Spot Fleet (required for Karpenter spot instances)"
}

# Karpenter module configuration
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = var.cluster_name

  # Use existing node IAM role if specified
  create_node_iam_role = var.create_node_iam_role
  node_iam_role_arn    = local.has_node_iam_role_arn ? var.node_iam_role_arn : null

  # Controller IAM role settings (IRSA role)
  enable_irsa                     = true
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_iam_role                 = false

  # Pod identity settings - disable as we'll use IRSA instead
  enable_pod_identity = false

  # Create access entry for Karpenter nodes
  create_access_entry = var.create_access_entry
  access_entry_type   = var.access_entry_type

  # Instance profile settings
  create_instance_profile = var.create_instance_profile

  tags = var.tags
}

# Add SSM policy for node management if using existing role
resource "aws_iam_role_policy_attachment" "karpenter_ssm" {
  count      = local.has_node_iam_role_arn && var.attach_ssm_policy ? 1 : 0
  role       = local.node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Add additional Karpenter-specific permissions if using existing role
resource "aws_iam_role_policy" "karpenter_additional" {
  count = local.has_node_iam_role_arn && var.create_additional_policy ? 1 : 0
  name  = "karpenter-additional-permissions"
  role  = local.node_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ssm:GetParameter"
        ]
        Resource = "*"
      }
    ]
  })
}