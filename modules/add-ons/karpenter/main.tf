

/**
 * # Karpenter Module
 *
 * This module creates an IAM role for Karpenter node provisioner.
 */

locals {
  # Module name for resource naming
  name = "karpenter"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.karpenter[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "karpenter" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "karpenter" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.karpenter[0].json
  name               = local.role_name
  tags               = var.tags
}

# Karpenter controller policy
data "aws_iam_policy_document" "karpenter_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:CreateTags",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
      "pricing:GetProducts",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "karpenter" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Karpenter"
  policy      = data.aws_iam_policy_document.karpenter_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.karpenter[0].arn
  role       = aws_iam_role.karpenter[0].name
}

