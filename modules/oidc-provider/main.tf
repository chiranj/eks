/**
 * # OIDC Provider Module
 *
 * This module creates an IAM OIDC provider for EKS clusters.
 */

locals {
  thumbprint = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  ]
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = local.thumbprint
  url             = var.oidc_url

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-oidc-provider"
    }
  )
}