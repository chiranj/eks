/**
 * # Amazon EBS CSI Driver Module
 *
 * This module creates an IAM role for the Amazon EBS CSI Driver.
 */

locals {
  # Module name for resource naming
  name = "ebs-csi-driver"

  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.ebs_csi[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "ebs_csi" {
  count = var.create_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# Use AWS managed policy for EBS CSI Driver
data "aws_iam_policy" "ebs_csi" {
  name = "AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "ebs_csi" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.ebs_csi[0].json
  name               = local.role_name
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = data.aws_iam_policy.ebs_csi.arn
  role       = aws_iam_role.ebs_csi[0].name
}