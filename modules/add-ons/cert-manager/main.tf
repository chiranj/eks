/**
 * # Cert Manager Module
 *
 * This module creates an IAM role for Cert Manager to manage Route 53 records for DNS01 challenge.
 */

locals {
  # Module name for resource naming
  name = "cert-manager"

  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.cert_manager[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "cert_manager" {
  count = var.create_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "cert_manager" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Cert Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:GetChange"
        ],
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListTagsForResource"
        ],
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "cert_manager" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.cert_manager[0].json
  name               = local.role_name
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.cert_manager[0].arn
  role       = aws_iam_role.cert_manager[0].name
}