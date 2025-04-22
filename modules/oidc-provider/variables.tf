variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_url" {
  description = "The URL of the OIDC Provider from EKS"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}