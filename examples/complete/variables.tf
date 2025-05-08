# GitLab variables are now embedded in the module itself
# No need for users to provide these sensitive values

# Optional custom IAM role for GitLab CI/CD
variable "gitlab_aws_role_arn" {
  description = "IAM role ARN to be assumed by GitLab CI/CD for deploying resources"
  type        = string
  default     = "" # Empty string means use the default AWS_ROLE_TO_ASSUME from GitLab CI/CD variables
}

# Custom AMI settings
variable "node_group_ami_id" {
  description = "Custom AMI ID for EKS worker nodes (default for all node groups)"
  type        = string
  default     = ""
}

# Variable removed as it's no longer needed - launch templates are now managed internally

# Organization policy required tag
variable "component_id" {
  description = "Value for the ComponentID tag required by organizational policy"
  type        = string
  default     = "aws-eks-cluster" # Default value for the ComponentID tag
}