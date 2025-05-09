

/**
 * # KEDA (Kubernetes Event-driven Autoscaling) Module
 *
 * This module creates an IAM role for KEDA.
 */

locals {
  # Module name for resource naming
  name = "keda"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.keda[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "keda" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:keda:keda-operator"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "keda" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.keda[0].json
  name               = local.role_name
  tags               = var.tags
}

# KEDA policy for CloudWatch and SQS
data "aws_iam_policy_document" "keda_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:DescribeAlarms",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListQueueTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "keda" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for KEDA"
  policy      = data.aws_iam_policy_document.keda_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "keda" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.keda[0].arn
  role       = aws_iam_role.keda[0].name
}

