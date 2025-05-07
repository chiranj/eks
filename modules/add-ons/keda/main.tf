/**
 * # KEDA IAM Role Module
 *
 * This module creates the necessary IAM roles and policies for the KEDA add-on.
 */

locals {
  name             = "keda"
  create_resources = var.create_role
  role_name        = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn         = var.create_role ? aws_iam_role.this[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "this" {
  count = local.create_resources ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:sub"
      values   = ["system:serviceaccount:keda:${local.name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  provider = aws.iam_admin
  
  count              = local.create_resources ? 1 : 0
  name        = "${var.cluster_name}-${local.name}"
  assume_role_policy = data.aws_iam_policy_document.this[0].json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  provider = aws.iam_admin
  
  count       = local.create_resources ? 1 : 0
  name        = "${var.cluster_name}-${local.name}"
  description = "IAM policy for KEDA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "sqs:GetQueueAttributes",
          "sqs:ListQueues",
          "sqs:ListQueueTags",
          "dynamodb:DescribeTable",
          "dynamodb:ListTables",
          "dynamodb:DescribeStream"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  provider = aws.iam_admin
  
  count      = local.create_resources ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.this[0].arn
}