variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider"
  type        = string
}

variable "create_role" {
  description = "Whether to create the IAM role"
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name of the IAM role to create or use (if create_role is false, this must be an existing role name)"
  type        = string
  default     = ""
}

variable "existing_role_arn" {
  description = "ARN of an existing IAM role to use (if create_role is false, this must be provided)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "iam_role_provider" {
  description = "AWS provider to use for IAM role and policy creation"
  type        = any
  default     = null
}
