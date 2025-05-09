

/**
 * # Secrets Manager Module
 *
 * This module creates an IAM role for AWS Secrets Manager integration.
 */

locals {
  # Module name for resource naming
  name = "secrets-manager"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.secrets_manager[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "secrets_manager" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:kube-system:secrets-store-csi-driver"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "secrets_manager" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.secrets_manager[0].json
  name               = local.role_name
  tags               = var.tags
}

# SecretsManager policy
data "aws_iam_policy_document" "secrets_manager_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "secrets_manager" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_manager_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_manager" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.secrets_manager[0].arn
  role       = aws_iam_role.secrets_manager[0].name
}

