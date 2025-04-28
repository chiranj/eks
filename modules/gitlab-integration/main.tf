/**
 * # GitLab Integration Module
 *
 * This module handles the integration with GitLab CI/CD pipelines for installing Kubernetes components.
 */

locals {
  payload = jsonencode({
    cluster = {
      name                  = var.cluster_name
      endpoint              = var.cluster_endpoint
      certificate_authority = var.cluster_ca_data
      oidc_provider_arn     = var.oidc_provider_arn
      region                = data.aws_region.current.name
    }
    addons = var.addons_config
    deployment = {
      aws_role_arn = var.aws_role_arn != "" ? var.aws_role_arn : null
    }
  })
}

data "aws_region" "current" {}

resource "null_resource" "trigger_gitlab_pipeline" {
  triggers = {
    cluster_name = var.cluster_name
    addons       = jsonencode(var.addons_config)
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl --request POST \
        --url "https://gitlab.com/api/v4/projects/${var.gitlab_project_id}/trigger/pipeline" \
        --form "token=${var.gitlab_token}" \
        --form "ref=${var.gitlab_pipeline_ref}" \
        --form "variables[CLUSTER_CONFIG]=${local.payload}"
    EOT
  }
}