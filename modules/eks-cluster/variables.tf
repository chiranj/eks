variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "create_cluster_iam_role" {
  description = "Controls if the EKS cluster IAM role should be created by Terraform"
  type        = bool
  default     = true
}

variable "cluster_iam_role_arn" {
  description = "Existing IAM role ARN for the EKS cluster (required if create_cluster_iam_role is false)"
  type        = string
  default     = ""
}

variable "create_node_iam_role" {
  description = "Controls if the EKS node IAM role should be created by Terraform"
  type        = bool
  default     = true
}

variable "node_iam_role_arn" {
  description = "Existing IAM role ARN for the EKS node groups (required if create_node_iam_role is false)"
  type        = string
  default     = ""
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
  description = "Map of EKS managed node group definitions"
  type        = any
  default     = {}
}

variable "use_existing_launch_templates" {
  description = "Whether to use pre-created launch templates instead of creating new ones"
  type        = bool
  default     = false
}

variable "launch_template_arns" {
  description = "Map of node group names to existing launch template ARNs to use (deprecated, use launch_template_ids instead)"
  type        = map(string)
  default     = {}
}

variable "launch_template_ids" {
  description = "Map of node group names to existing launch template IDs to use"
  type        = map(string)
  default     = {}
}

variable "launch_template_versions" {
  description = "Map of node group names to existing launch template versions to use"
  type        = map(string)
  default     = {}
}

variable "service_ipv4_cidr" {
  description = "Service IPv4 CIDR for the Kubernetes cluster"
  type        = string
  default     = "172.20.0.0/16"
}

variable "cluster_ip_family" {
  description = "IP family for the cluster (ipv4 or ipv6)"
  type        = string
  default     = "ipv4"
}

variable "manage_aws_auth_configmap" {
  description = "Whether to manage the aws-auth ConfigMap (for backward compatibility)"
  type        = bool
  default     = true
}

variable "aws_auth_roles" {
  description = "List of IAM roles to add to the aws-auth ConfigMap (for backward compatibility)"
  type        = list(any)
  default     = []
}

variable "aws_auth_users" {
  description = "List of IAM users to add to the aws-auth ConfigMap (for backward compatibility)"
  type        = list(any)
  default     = []
}

variable "eks_access_entries" {
  description = "Map of access entries to add to the cluster (EKS module v20+)"
  type        = any
  default     = {}
}

variable "component_id" {
  description = "Value for the ComponentID tag required by organizational policy"
  type        = string
  default     = "true"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "node_group_ami_id" {
  description = "AMI ID to use for all EKS managed node groups (optional)"
  type        = string
  default     = ""
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver service account"
  type        = string
  default     = ""
}

variable "efs_csi_driver_role_arn" {
  description = "IAM role ARN for EFS CSI Driver service account"
  type        = string
  default     = ""
}

variable "external_dns_role_arn" {
  description = "IAM role ARN for External DNS service account"
  type        = string
  default     = ""
}

variable "cert_manager_role_arn" {
  description = "IAM role ARN for Cert Manager service account"
  type        = string
  default     = ""
}