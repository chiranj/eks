/**
 * # Amazon EFS CSI Driver Module
 *
 * This module creates an IAM role for the Amazon EFS CSI Driver.
 */

locals {
  # Module name for resource naming
  name = "efs-csi-driver"

  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.efs_csi[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "efs_csi" {
  count = var.create_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "efs_csi" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for Amazon EFS CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ],
        Resource = "*",
        Condition = {
          StringLike = {
            "aws:RequestTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:DeleteAccessPoint"
        ],
        Resource = "*",
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "efs_csi" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.efs_csi[0].json
  name               = local.role_name
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.efs_csi[0].arn
  role       = aws_iam_role.efs_csi[0].name
}