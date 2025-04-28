/**
 * # AWS Secrets & Configuration Provider (ASCP) IAM Role Module
 *
 * This module creates the necessary IAM roles and policies for the AWS Secrets & Configuration Provider add-on.
 */

locals {
  name = "secrets-manager"
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^arn:aws:iam::[0-9]+:oidc-provider\\//", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${local.name}"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-${local.name}"
  assume_role_policy = data.aws_iam_policy_document.this.json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-${local.name}"
  description = "IAM policy for AWS Secrets & Configuration Provider"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter*"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}