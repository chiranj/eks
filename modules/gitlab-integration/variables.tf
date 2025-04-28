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

variable "aws_role_arn" {
  description = "IAM role ARN to be assumed by GitLab CI/CD for deploying resources"
  type        = string
  default     = ""
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
  type        = map(any)
  # Complex type definition to support different add-on configurations:
  # Standard add-ons use this structure:
  # {
  #   enabled      = bool
  #   iam_role_arn = string  
  # }
  # 
  # External DNS uses additional fields:
  # {
  #   enabled      = bool
  #   iam_role_arn = string
  #   hosted_zone_id = string
  #   hosted_zone_name_servers = list(string) 
  # }
}