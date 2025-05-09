

/**
 * # AWS Distro for OpenTelemetry (ADOT) Module
 *
 * This module creates an IAM role for the AWS Distro for OpenTelemetry.
 */

locals {
  # Module name for resource naming
  name = "adot"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.adot[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "adot" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:opentelemetry-operator-system:opentelemetry-operator"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "adot" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.adot[0].json
  name               = local.role_name
  tags               = var.tags
}

# ADOT permissions policy
data "aws_iam_policy_document" "adot_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "adot" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for AWS Distro for OpenTelemetry"
  policy      = data.aws_iam_policy_document.adot_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "adot" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.adot[0].arn
  role       = aws_iam_role.adot[0].name
}

