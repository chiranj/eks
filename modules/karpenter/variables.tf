variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  type        = string
}

variable "create_controller_iam_role" {
  description = "Whether to create a new IAM role for the Karpenter controller (IRSA)"
  type        = bool
  default     = true
}


variable "create_node_iam_role" {
  description = "Whether to create a new IAM role for the nodes or use an existing one"
  type        = bool
  default     = true
}

variable "node_iam_role_arn" {
  description = "ARN of the existing IAM role used by EKS nodes"
  type        = string
  default     = ""
}

variable "create_access_entry" {
  description = "Whether to create an access entry for Karpenter nodes"
  type        = bool
  default     = true
}

variable "access_entry_type" {
  description = "Type of access entry for Karpenter nodes"
  type        = string
  default     = "EC2_LINUX"
}

variable "create_queue" {
  description = "Whether to create SQS queue for spot interruption handling"
  type        = bool
  default     = true
}

variable "create_instance_profile" {
  description = "Whether to create instance profile for Karpenter nodes"
  type        = bool
  default     = true
}


variable "attach_ssm_policy" {
  description = "Whether to attach the SSM policy to the node role"
  type        = bool
  default     = true
}

variable "create_additional_policy" {
  description = "Whether to create additional IAM policy for Karpenter"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

