

/**
 * # Fluent Bit Module
 *
 * This module creates an IAM role for Fluent Bit log agent.
 */

locals {
  # Module name for resource naming
  name = "fluent-bit"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.fluent_bit[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "fluent_bit" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:logging:fluent-bit"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.fluent_bit[0].json
  name               = local.role_name
  tags               = var.tags
}

# Fluent Bit policy
data "aws_iam_policy_document" "fluent_bit_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "fluent_bit" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Fluent Bit"
  policy      = data.aws_iam_policy_document.fluent_bit_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.fluent_bit[0].arn
  role       = aws_iam_role.fluent_bit[0].name
}

