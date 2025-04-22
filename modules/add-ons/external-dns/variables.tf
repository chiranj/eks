variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider"
  type        = string
}

variable "hosted_zone_source" {
  description = "Source for the hosted zone - 'existing' to use an existing hosted zone or 'create' to create a new one"
  type        = string
  default     = "existing"
}

variable "existing_hosted_zone_id" {
  description = "ID of an existing Route53 hosted zone (required if hosted_zone_source is 'existing')"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain name to use for creating a new Route53 hosted zone (required if hosted_zone_source is 'create')"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}