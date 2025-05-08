/**
 * # Amazon EBS CSI Driver Module
 *
 * This module creates an IAM role for the Amazon EBS CSI Driver.
 */

data "aws_iam_policy_document" "ebs_csi" {
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

data "aws_iam_policy" "ebs_csi" {
  name = "AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "ebs_csi" {
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.ebs_csi.json
  name               = "${var.cluster_name}-ebs-csi-driver"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attachment" {
  provider   = aws.iam_admin
  policy_arn = data.aws_iam_policy.ebs_csi.arn
  role       = aws_iam_role.ebs_csi.name
}