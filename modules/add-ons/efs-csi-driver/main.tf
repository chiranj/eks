/**
 * # Amazon EFS CSI Driver Module
 *
 * This module creates an IAM role for the Amazon EFS CSI Driver.
 */

data "aws_iam_policy_document" "efs_csi" {
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
  name        = "${var.cluster_name}-AmazonEFSCSIDriverPolicy"
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
  assume_role_policy = data.aws_iam_policy_document.efs_csi.json
  name               = "${var.cluster_name}-efs-csi-driver"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi_attachment" {
  policy_arn = aws_iam_policy.efs_csi.arn
  role       = aws_iam_role.efs_csi.name
}