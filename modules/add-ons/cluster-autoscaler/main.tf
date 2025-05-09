

/**
 * # Cluster Autoscaler Module
 *
 * This module creates an IAM role for the Kubernetes Cluster Autoscaler.
 */

locals {
  # Module name for resource naming
  name = "cluster-autoscaler"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.autoscaler[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "autoscaler" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "autoscaler" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.autoscaler[0].json
  name               = local.role_name
  tags               = var.tags
}

# Cluster Autoscaler policy
data "aws_iam_policy_document" "autoscaler_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "autoscaler" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Kubernetes Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.autoscaler_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "autoscaler" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.autoscaler[0].arn
  role       = aws_iam_role.autoscaler[0].name
}

