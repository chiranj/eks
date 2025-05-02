variable "gitlab_host" {
  description = "The GitLab host (default: gitlab.com)"
  type        = string
  default     = "gitlab.com"
}

variable "gitlab_project_id" {
  description = "The GitLab project ID"
  type        = string
}

variable "gitlab_namespace_path" {
  description = "The GitLab namespace path (default: derived from project ID)"
  type        = string
  default     = ""
}

variable "gitlab_ref_type" {
  description = "The GitLab reference type (branch, tag, etc.)"
  type        = string
  default     = "branch"
}

variable "gitlab_ref" {
  description = "The GitLab reference (branch name, tag name, etc.)"
  type        = string
  default     = "main"
}

variable "gitlab_audience" {
  description = "The audience value for OIDC (default: https://<gitlab_host>)"
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Whether to create a new OIDC provider for GitLab"
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name of the IAM role to create (default: GitLabDeploymentRole-<cluster_name>)"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "thumbprint_list" {
  description = "List of server certificate thumbprints for the OIDC provider's server certificate(s)"
  type        = list(string)
  default     = ["b884161ae9de7ac8e421655af4727a5e43f1e817"] # Common thumbprint for GitLab.com
}

variable "managed_policy_arns" {
  description = "List of managed IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "custom_policy_arns" {
  description = "List of custom IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "additional_policy_json" {
  description = "Additional policy JSON to attach to the role"
  type        = string
  default     = ""
}

variable "create_eks_access_policy" {
  description = "Whether to attach the AmazonEKSClusterPolicy to the role"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}