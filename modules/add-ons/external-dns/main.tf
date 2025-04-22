/**
 * # External DNS IAM Role Module
 *
 * This module creates the necessary IAM roles and policies for the External DNS add-on.
 * It also optionally creates a new Route53 hosted zone if specified.
 */

locals {
  name = "external-dns"
  
  # Determine if we should create a new hosted zone
  create_hosted_zone = var.hosted_zone_source == "create" && var.domain != ""
  
  # Determine which hosted zone ID to use
  hosted_zone_id = local.create_hosted_zone ? aws_route53_zone.this[0].id : var.existing_hosted_zone_id
  
  # Determine the ARN pattern based on whether we have a specific hosted zone or want to allow all
  hosted_zone_arn_pattern = local.hosted_zone_id != "" ? "arn:aws:route53:::hostedzone/${local.hosted_zone_id}" : "arn:aws:route53:::hostedzone/*"
}

# Create Route53 hosted zone if requested
resource "aws_route53_zone" "this" {
  count = local.create_hosted_zone ? 1 : 0
  
  name = var.domain
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${var.domain}"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
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
  description = "IAM policy for External DNS"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [local.hosted_zone_arn_pattern]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}