terraform {
  # Backend configuration will be injected by GitLab CI/CD
  backend "http" {
    # These values will be populated by GitLab CI
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.0"
}