variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "A list of subnet IDs where the EKS control plane (ENIs) will be provisioned"
  type        = list(string)
  default     = null
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions. Can include ami_id to specify a custom AMI."
  type        = any
  default     = {}
}

variable "manage_aws_auth_configmap" {
  description = "Whether to manage the aws-auth ConfigMap"
  type        = bool
  default     = true
}

variable "aws_auth_roles" {
  description = "List of IAM roles to add to the aws-auth ConfigMap"
  type        = list(any)
  default     = []
}

variable "aws_auth_users" {
  description = "List of IAM users to add to the aws-auth ConfigMap"
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}