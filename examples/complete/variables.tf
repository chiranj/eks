# GitLab variables are now embedded in the module itself
# No need for users to provide these sensitive values

# Optional custom IAM role for GitLab CI/CD
variable "gitlab_aws_role_arn" {
  description = "IAM role ARN to be assumed by GitLab CI/CD for deploying resources"
  type        = string
  default     = "" # Empty string means use the default AWS_ROLE_TO_ASSUME from GitLab CI/CD variables
}