# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test/Lint Commands
- Init: `terraform init`
- Plan: `terraform plan`
- Apply: `terraform apply`
- Lint: `terraform fmt -check -recursive`
- Validate: `terraform validate`
- Test: `cd examples/complete && terraform init && terraform validate`

## Code Style Guidelines
- Terraform indentation: 2 spaces
- Use terraform-aws-modules where possible
- Follow Terraform best practices for module organization
- Document all variables with descriptions and data types
- Use conditional expressions for optional components
- Tag all resources consistently for cost tracking
- Follow proper naming convention: lowercase with hyphens (e.g., eks-cluster)
- Group related resources in the same module
- Keep modules focused and composable
- Security: Implement least privilege IAM permissions and use OIDC for authentication

## Project Scope

EKS Service Catalog Terraform Architecture Summary
Overview
Create an AWS Service Catalog product that deploys EKS clusters with optional add-ons, using a hybrid deployment approach where Terraform provisions AWS infrastructure and GitLab CI/CD installs Kubernetes components.
Key Components
1. Service Catalog Product Parameters

Core cluster parameters (VPC, subnets, node groups, etc.)
Add-on selection dropdowns with Yes/No options
Sensitive GitLab token for pipeline triggering

2. Terraform Module Structure

Main EKS cluster using terraform-aws-modules/eks
Conditional IAM role modules for each add-on (only created if selected)
OIDC providers for EKS and GitLab authentication
JSON payload generation for GitLab pipeline
Pipeline trigger using null_resource and curl

3. Dynamic IAM Role Creation

Each add-on gets its own conditional module for IAM/IRSA roles
Roles are created only when the add-on is selected
Proper OIDC provider bindings for service accounts
Least-privilege permissions per component

4. GitLab Pipeline Integration

Receives structured JSON payload with cluster info and add-on selections
Authenticates using OIDC federation (no long-term credentials)
Installs only selected components using conditional job rules
Uses local Helm charts with custom values

Extensibility Pattern for New Add-ons

Add new parameter in Service Catalog template
Create conditional IAM module for the add-on
Include add-on data in GitLab payload
Add corresponding Helm chart and pipeline job

Security Considerations

Sensitive GitLab token stored in Service Catalog template
OIDC-based authentication for all operations
IAM roles with minimal required permissions
No cross-account access required

Output Structure
All Terraform outputs are formatted as JSON and sent to GitLab, including:

Cluster details (name, endpoint, OIDC provider)
Add-on selections and corresponding IAM role ARNs
Authentication details for GitLab OIDC

This architecture provides a scalable, secure, and self-service EKS deployment mechanism that respects account boundaries while enabling comprehensive cluster configuration.