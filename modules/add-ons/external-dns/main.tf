/**
 * # External DNS Module
 *
 * This module creates an IAM role for External DNS to manage Route 53 records.
 */

locals {
  # Module name for resource naming
  name = "external-dns"

  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.external_dns[0].arn : var.existing_role_arn

  # Route53 hosted zone configuration
  create_hosted_zone = var.create_role && var.hosted_zone_source == "create"
}

data "aws_iam_policy_document" "external_dns" {
  count = var.create_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_route53_zone" "zone" {
  count = local.create_hosted_zone ? 1 : 0

  name          = var.domain
  force_destroy = true
  tags          = var.tags
}

resource "aws_iam_policy" "external_dns" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for External DNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = local.create_hosted_zone ? [
          "arn:aws:route53:::hostedzone/${aws_route53_zone.zone[0].id}"
          ] : [
          "arn:aws:route53:::hostedzone/${var.existing_hosted_zone_id}"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        Resource = ["*"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "external_dns" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.external_dns[0].json
  name               = local.role_name
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.external_dns[0].arn
  role       = aws_iam_role.external_dns[0].name
}