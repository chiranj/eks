variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.29"
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

variable "node_group_ami_id" {
  description = "Custom AMI ID for EKS worker nodes. If specified, this AMI will be used for all node groups unless overridden in the eks_managed_node_groups configuration."
  type        = string
  default     = ""
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

variable "vpc_mode" {
  description = "Select whether to use an existing VPC or create a new one"
  type        = string
  default     = "existing"
  validation {
    condition     = contains(["existing", "create_new"], var.vpc_mode)
    error_message = "The vpc_mode must be either 'existing' or 'create_new'."
  }
}

variable "create_vpc" {
  description = "Controls if VPC should be created"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC (only used if creating a new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones for the new VPC (only used if creating a new VPC)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller add-on"
  type        = bool
  default     = false
}

variable "node_scaling_method" {
  description = "Select node scaling method (Karpenter or Cluster Autoscaler)"
  type        = string
  default     = "karpenter"
  validation {
    condition     = contains(["karpenter", "cluster_autoscaler", "none"], var.node_scaling_method)
    error_message = "The node_scaling_method must be one of 'karpenter', 'cluster_autoscaler', or 'none'."
  }
}

variable "enable_keda" {
  description = "Enable KEDA for pod autoscaling (works well with Karpenter)"
  type        = bool
  default     = false
}

variable "enable_external_dns" {
  description = "Enable External DNS add-on"
  type        = bool
  default     = false
}

variable "external_dns_hosted_zone_source" {
  description = "Source for the External DNS hosted zone - 'existing' to use an existing hosted zone or 'create' to create a new one"
  type        = string
  default     = "existing"
  validation {
    condition     = contains(["existing", "create"], var.external_dns_hosted_zone_source)
    error_message = "The external_dns_hosted_zone_source must be either 'existing' or 'create'."
  }
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
  type        = bool
  default     = false
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets & Configuration Provider (ASCP) add-on"
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Enable Cert Manager add-on"
  type        = bool
  default     = false
}

variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller add-on"
  type        = bool
  default     = false
}

variable "enable_adot" {
  description = "Enable AWS Distro for OpenTelemetry (ADOT) add-on"
  type        = bool
  default     = false
}

variable "enable_fluent_bit" {
  description = "Enable Fluent Bit for log collection add-on"
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Enable Amazon EBS CSI Driver add-on"
  type        = bool
  default     = true
}

variable "enable_efs_csi_driver" {
  description = "Enable Amazon EFS CSI Driver add-on"
  type        = bool
  default     = false
}

variable "trigger_gitlab_pipeline" {
  description = "Enable triggering GitLab pipeline for Kubernetes components installation"
  type        = bool
  default     = false
}

variable "gitlab_token" {
  description = "GitLab token for pipeline triggering (embedded in the module, not required to be provided by users)"
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

variable "gitlab_aws_role_arn" {
  description = "DEPRECATED: Use the new OIDC variables instead. IAM role ARN to be assumed by GitLab CI/CD for deploying resources (if not specified, a role will be created)"
  type        = string
  default     = "" # Empty string means a role will be created
}

# GitLab OIDC Integration
variable "create_gitlab_oidc_provider" {
  description = "Whether to create an OIDC provider for GitLab"
  type        = bool
  default     = true
}

variable "gitlab_oidc_host" {
  description = "The GitLab host for OIDC (default: gitlab.com)"
  type        = string
  default     = "gitlab.com"
}

variable "gitlab_oidc_thumbprint" {
  description = "Thumbprint for the GitLab OIDC provider"
  type        = list(string)
  default     = ["b884161ae9de7ac8e421655af4727a5e43f1e817"]
}

variable "gitlab_oidc_ref_type" {
  description = "The GitLab reference type (branch, tag, etc.)"
  type        = string
  default     = "branch"
}

variable "gitlab_oidc_role_name" {
  description = "Name for the GitLab deployment role"
  type        = string
  default     = "" # Will default to GitLabDeploymentRole-<cluster_name>
}

# EKS Access Entries (v20+ authentication)
variable "eks_access_entries" {
  description = "Map of access entries to add to the EKS cluster"
  type        = any
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}