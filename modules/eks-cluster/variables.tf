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
  description = "Map of EKS managed node group definitions"
  type        = any
  default     = {}
}

variable "create_launch_templates_for_custom_amis" {
  description = "Whether to create launch templates for node groups with custom AMIs"
  type        = bool
  default     = true
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}