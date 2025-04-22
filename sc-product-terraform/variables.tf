variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_mode" {
  description = "Select whether to use an existing VPC or create a new one"
  type        = string
  default     = "existing"
  validation {
    condition     = contains(["existing", "create_new"], var.vpc_mode)
    error_message = "The vpc_mode must be either 'existing' or 'create_new'."
  }
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster (required if using an existing VPC)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned (required if using an existing VPC)"
  type        = list(string)
  default     = []
}

variable "control_plane_subnet_ids" {
  description = "A list of subnet IDs where the EKS control plane (ENIs) will be provisioned (required if using an existing VPC)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC (only used if creating a new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = string
  default     = "true"
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = string
  default     = "true"
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "eks-node-group"
}

variable "node_group_instance_type" {
  description = "Instance type for the EKS node group"
  type        = string
  default     = "t3.medium"
}

variable "node_group_desired_capacity" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 5
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller add-on"
  type        = string
  default     = "true"
}

variable "node_scaling_method" {
  description = "Select node scaling method (Karpenter or Cluster Autoscaler)"
  type        = string
  default     = "karpenter"
}

variable "enable_keda" {
  description = "Enable KEDA for pod autoscaling (works well with Karpenter)"
  type        = string
  default     = "false"
}

variable "enable_external_dns" {
  description = "Enable External DNS add-on"
  type        = string
  default     = "false"
}

variable "external_dns_hosted_zone_source" {
  description = "Source for the External DNS hosted zone - 'existing' to use an existing hosted zone or 'create' to create a new one"
  type        = string
  default     = "existing"
}

variable "external_dns_existing_hosted_zone_id" {
  description = "ID of an existing Route53 hosted zone to use with External DNS (required if external_dns_hosted_zone_source is 'existing')"
  type        = string
  default     = ""
}

variable "external_dns_domain" {
  description = "Domain name to use for creating a new Route53 hosted zone (required if external_dns_hosted_zone_source is 'create')"
  type        = string
  default     = ""
}

variable "enable_prometheus" {
  description = "Enable Prometheus add-on"
  type        = string
  default     = "false"
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets & Configuration Provider (ASCP) add-on"
  type        = string
  default     = "false"
}

variable "enable_cert_manager" {
  description = "Enable Cert Manager add-on"
  type        = string
  default     = "false"
}

variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller add-on"
  type        = string
  default     = "false"
}

variable "enable_adot" {
  description = "Enable AWS Distro for OpenTelemetry (ADOT) add-on"
  type        = string
  default     = "false"
}

variable "enable_fluent_bit" {
  description = "Enable Fluent Bit for log collection add-on"
  type        = string
  default     = "false"
}

variable "trigger_gitlab_pipeline" {
  description = "Enable triggering GitLab pipeline for Kubernetes components installation"
  type        = string
  default     = "true"
}

variable "gitlab_token" {
  description = "GitLab token for pipeline triggering"
  type        = string
  sensitive   = true
  default     = "glptt-abc123def456ghi789" # Replace with your actual GitLab pipeline trigger token
}

variable "gitlab_project_id" {
  description = "GitLab project ID for pipeline triggering"
  type        = string
  default     = "12345678" # Replace with your actual GitLab project ID
}

variable "gitlab_pipeline_ref" {
  description = "GitLab pipeline reference (branch/tag) to use"
  type        = string
  default     = "main"
}