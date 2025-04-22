variable "gitlab_token" {
  description = "GitLab token for pipeline triggering"
  type        = string
  sensitive   = true
}

variable "gitlab_project_id" {
  description = "GitLab project ID for pipeline triggering"
  type        = string
}

variable "gitlab_pipeline_ref" {
  description = "GitLab pipeline reference (branch/tag) to use"
  type        = string
  default     = "main"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API"
  type        = string
}

variable "cluster_ca_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
  sensitive   = true
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider"
  type        = string
}

variable "addons_config" {
  description = "Configuration for add-ons to be installed via GitLab pipeline"
  type        = map(object({
    enabled      = bool
    iam_role_arn = string
  }))
}