/**
 * # GitLab Integration Module
 *
 * This module exports Terraform outputs as files that can be used by GitLab CI/CD parent-child pipelines
 * for installing Kubernetes components.
 */

locals {
  addon_data = {
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
  }

  # Generate environment variables for simple key-value pairs
  env_vars = concat(
    [
      "CLUSTER_NAME=${var.cluster_name}",
      "CLUSTER_ENDPOINT=${var.cluster_endpoint}",
      "CLUSTER_CA_DATA=${var.cluster_ca_data}",
      "OIDC_PROVIDER_ARN=${var.oidc_provider_arn}",
      "AWS_REGION=${data.aws_region.current.name}",
      "AWS_ROLE_ARN=${var.aws_role_arn}"
    ],
    [for addon_name, config in var.addons_config :
      config.enabled ? "${upper(replace(addon_name, "-", "_"))}_ROLE_ARN=${config.iam_role_arn}" : ""
    ]
  )
}

data "aws_region" "current" {}

# Export as JSON file (for complex data)
resource "local_file" "addon_resources_json" {
  content  = jsonencode(local.addon_data)
  filename = "${path.module}/terraform-outputs.json"
}

# Export as dotenv file (for environment variables)
resource "local_file" "addon_resources_env" {
  content  = join("\n", [for line in local.env_vars : line if line != ""])
  filename = "${path.module}/terraform-outputs.env"
}