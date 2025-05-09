

/**
 * # NGINX Ingress Controller Module
 *
 * This module creates an IAM role for the NGINX Ingress Controller.
 */

locals {
  # Module name for resource naming
  name = "nginx-ingress"
  
  # IAM role configuration
  create_role = var.create_role
  role_name   = var.create_role ? (var.role_name != "" ? var.role_name : "${var.cluster_name}-${local.name}") : var.role_name
  role_arn    = var.create_role ? aws_iam_role.nginx[0].arn : var.existing_role_arn
}

data "aws_iam_policy_document" "nginx" {
  count = var.create_role ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${substr(var.oidc_provider_arn, 8, length(var.oidc_provider_arn) - 8)}:sub"
      values   = ["system:serviceaccount:ingress-nginx:ingress-nginx-controller"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "nginx" {
  count              = var.create_role ? 1 : 0
  provider           = aws.iam_admin
  assume_role_policy = data.aws_iam_policy_document.nginx[0].json
  name               = local.role_name
  tags               = var.tags
}

# NGINX Ingress Controller permissions for NLB integration
data "aws_iam_policy_document" "nginx_policy" {
  count = var.create_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "nginx" {
  count       = var.create_role ? 1 : 0
  provider    = aws.iam_admin
  name        = local.role_name
  description = "IAM policy for NGINX Ingress Controller"
  policy      = data.aws_iam_policy_document.nginx_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "nginx" {
  count      = var.create_role ? 1 : 0
  provider   = aws.iam_admin
  policy_arn = aws_iam_policy.nginx[0].arn
  role       = aws_iam_role.nginx[0].name
}

