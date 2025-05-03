/**
 * # GitLab OIDC Integration Module
 *
 * This module creates an IAM OIDC provider for GitLab CI/CD and a role that can be assumed by GitLab pipelines.
 */

locals {
  gitlab_host    = var.gitlab_host != "" ? var.gitlab_host : "gitlab.com"
  oidc_audience  = var.gitlab_audience != "" ? var.gitlab_audience : "https://${local.gitlab_host}"
  namespace_path = var.gitlab_namespace_path != "" ? var.gitlab_namespace_path : var.gitlab_project_id

  # Generate role name if not specified
  role_name = var.role_name != "" ? var.role_name : "GitLabDeploymentRole-${var.cluster_name}"
}

# Get existing provider if it exists
data "aws_iam_openid_connect_provider" "gitlab" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.gitlab_host}"
}

# Create OIDC provider if needed
resource "aws_iam_openid_connect_provider" "gitlab" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://${local.gitlab_host}"
  client_id_list  = [local.oidc_audience]
  thumbprint_list = var.thumbprint_list

  tags = merge(
    var.tags,
    {
      Name = "gitlab-oidc-provider"
    }
  )
}

# Define the assume role policy for GitLab CI/CD
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.create_oidc_provider ? aws_iam_openid_connect_provider.gitlab[0].arn : data.aws_iam_openid_connect_provider.gitlab[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_host}:sub"
      values   = ["project_path:${local.namespace_path}:ref_type:${var.gitlab_ref_type}:ref:${var.gitlab_ref}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_host}:aud"
      values   = [local.oidc_audience]
    }
  }
}

# Create the GitLab deployment role
resource "aws_iam_role" "gitlab_deployment_role" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags               = var.tags
}

# Attach managed policies
resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.gitlab_deployment_role.name
  policy_arn = var.managed_policy_arns[count.index]
}

# Attach EKS cluster policy if enabled
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_eks_access_policy ? 1 : 0
  role       = aws_iam_role.gitlab_deployment_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Attach custom policies if provided
resource "aws_iam_role_policy_attachment" "custom_policy" {
  count      = length(var.custom_policy_arns)
  role       = aws_iam_role.gitlab_deployment_role.name
  policy_arn = var.custom_policy_arns[count.index]
}

# Create inline policy for additional permissions
resource "aws_iam_role_policy" "additional_permissions" {
  count  = var.additional_policy_json != "" ? 1 : 0
  name   = "AdditionalGitLabPermissions"
  role   = aws_iam_role.gitlab_deployment_role.id
  policy = var.additional_policy_json
}