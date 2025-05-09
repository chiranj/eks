

/**
 * # Prometheus Module
 *
 * This module creates an IAM role for Prometheus.
 */

locals {
  # Module name for resource naming
  name = "prometheus"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.prometheus[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "prometheus" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:monitoring:prometheus-server"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "prometheus" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.prometheus[0].json
  name               = local.role_name
  tags               = var.tags
}

# Prometheus policy for EC2 and CloudWatch integration
data "aws_iam_policy_document" "prometheus_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "prometheus" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Prometheus"
  policy      = data.aws_iam_policy_document.prometheus_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "prometheus" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.prometheus[0].arn
  role       = aws_iam_role.prometheus[0].name
}

