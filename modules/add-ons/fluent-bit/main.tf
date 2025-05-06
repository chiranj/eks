/**
 * # Fluent Bit IAM Role Module
 *
 * This module creates the necessary IAM roles and policies for the Fluent Bit add-on.
 */

locals {
  name             = "fluent-bit"
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
      values   = ["system:serviceaccount:logging:${local.name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  
  count              = local.create_resources ? 1 : 0
  name        = "${var.cluster_name}-${local.name}"
  assume_role_policy = data.aws_iam_policy_document.this[0].json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  
  count       = local.create_resources ? 1 : 0
  name        = "${var.cluster_name}-${local.name}"
  description = "IAM policy for Fluent Bit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:*:log-stream:*",
          "arn:aws:logs:*:*:log-group:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  
  count      = local.create_resources ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.this[0].arn
}