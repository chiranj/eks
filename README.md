# AWS Service Catalog - EKS Cluster with Add-ons

This repository contains Terraform modules to create an AWS Service Catalog product for EKS clusters with optional add-ons.

## Deployment Using GitLab CI/CD

This repository is designed to be deployed via GitLab CI/CD pipelines, providing a flexible and customizable approach to EKS cluster provisioning.

### GitLab CI/CD Integration

- The repository includes a `.gitlab-ci.yml` file that defines the deployment pipeline
- Users can include this pipeline in their own GitLab repositories to deploy EKS clusters
- Configuration is handled through CI/CD variables or a terraform.tfvars file
- Uses GitLab-managed Terraform state with cluster-specific state paths
- Dynamically creates AWS resources only for the add-ons you enable
- Built-in GitLab OIDC authentication with AWS:
  - Automatically creates a GitLab OIDC provider in AWS
  - Generates a properly configured IAM role for GitLab
  - Grants the role access to the EKS cluster through access entries
  - Enables secure, token-based authentication without static credentials

### How to Use in Your Project

1. Create a new GitLab project or use an existing one
2. Include our pipeline in your own `.gitlab-ci.yml`:

```yaml
include:
  - project: 'your-org/eks-module'
    ref: main
    file: '.gitlab-ci.yml'

variables:
  CLUSTER_NAME: "my-eks-cluster"
  VPC_ID: "vpc-12345"
  SUBNET_IDS: '["subnet-123", "subnet-456", "subnet-789"]'
  NODE_SCALING_METHOD: "karpenter"
  ENABLE_AWS_LOAD_BALANCER_CONTROLLER: "true"
  
  # GitLab ID variables (used for OIDC trust configuration)
  # These are automatically provided by GitLab runners
  # CI_JOB_JWT_V2: ${CI_JOB_JWT_V2}  # This gets injected automatically
  
  # Add other configuration options as needed
```

3. No additional AWS credentials are needed - the OIDC integration handles authentication securely
4. Run the pipeline to deploy your EKS cluster

For detailed instructions, see our [GitLab CI/CD Guide](./docs/gitlab-ci-guide.md).

## Architecture Overview

This solution implements a hybrid deployment approach where:
1. Terraform provisions AWS infrastructure (EKS cluster, IAM roles, OIDC providers)
2. GitLab CI/CD installs Kubernetes components (Helm charts, Kubernetes manifests)

## Key Components

### 1. Service Catalog Product Parameters
- Core cluster parameters (VPC, subnets, node groups, etc.)
- Support for custom AMIs via launch templates
- Add-on selection dropdowns with Yes/No options
- Sensitive GitLab token for pipeline triggering

### 2. Custom AMI Support
- Use your own AMIs for EKS worker nodes
- Automated launch template creation with proper bootstrap script
- Support per-node-group AMI configuration
- Properly configures custom AMIs to join the EKS cluster

### 3. Terraform Module Structure
- Main EKS cluster using `terraform-aws-modules/eks`
- Conditional IAM role modules for each add-on (only created if selected)
- OIDC providers for EKS and GitLab authentication
- JSON payload generation for GitLab pipeline
- Pipeline trigger using `null_resource` and `curl`

### 4. Dynamic IAM Role Creation
- Each add-on gets its own conditional module for IAM/IRSA roles
- Roles are created only when the add-on is selected
- Proper OIDC provider bindings for service accounts
- Least-privilege permissions per component

### 5. GitLab Pipeline Integration
- Receives structured JSON payload with cluster info and add-on selections
- Authenticates using OIDC federation (no long-term credentials)
- Installs only selected components using conditional job rules
- Uses local Helm charts with custom values

## Available Add-ons

### Core Add-ons
- CoreDNS (installed by default with EKS)
- kube-proxy (installed by default with EKS)
- vpc-cni (installed by default with EKS)
- Amazon EBS CSI Driver (enabled by default for persistent volumes)

### Optional Add-ons
- AWS Load Balancer Controller
- Node Scaling Options:
  - Karpenter (recommended, modern autoscaling)
  - Cluster Autoscaler (traditional autoscaling)
- KEDA (Kubernetes Event-driven Autoscaling)
- External DNS 
- Prometheus
- AWS Secrets & Configuration Provider (ASCP)
- Cert Manager
- NGINX Ingress Controller
- AWS Distro for OpenTelemetry (ADOT)
- Fluent Bit (log collection)
- Amazon EFS CSI Driver (optional, for ReadWriteMany volumes)

## Usage

1. Deploy this Terraform code to your AWS account
2. Create a Service Catalog product using the template in `service-catalog-template/`
3. Provision the product from Service Catalog with your desired parameters
4. The product will create the EKS cluster and trigger the GitLab pipeline for Kubernetes components

## Requirements

- Terraform >= 1.0.0
- AWS provider >= 4.0
- AWS CLI >= 2.0
- GitLab project for pipeline integration

## Security Considerations

- Sensitive GitLab token directly embedded in the Service Catalog template with NoEcho protection
- Token has limited pipeline-triggering scope only (not a full GitLab access token)
- OIDC-based authentication for all operations
- IAM roles with minimal required permissions
- No cross-account access required

### GitLab Token Security

The GitLab pipeline trigger token is embedded directly in the Service Catalog template with `NoEcho: true` to prevent it from appearing in CloudFormation logs and console. This token:

- Has limited scope (only triggers specific pipelines)
- Cannot access repositories or other GitLab resources
- Is only used for the initial pipeline trigger to deploy Kubernetes add-ons
- Can be rotated by updating the template and redeploying (without affecting existing clusters)

## Adding New Add-ons

To add a new add-on to the Service Catalog product:

1. Add a new parameter in the Service Catalog template
2. Create a conditional IAM module for the add-on in `modules/add-ons/`
3. Include the add-on data in the GitLab payload
4. Add corresponding Helm chart and pipeline job in the GitLab repository
Error: creating IAM Role (eks132-dev-adot): operation error IAM: CreateRole, https response error StatusCode: 403, RequestID: 952aafad-6adc-4527-b1b7-5654312b09b4, api error AccessDenied: User: arn:aws:sts::583541782477:assumed-role/uacs-gitlab-runner-role-1/i-0da1b3e8ffe8e22b7 is not authorized to perform: iam:CreateRole on resource: arn:aws:iam::583541782477:role/eks132-dev-adot with an explicit deny in an identity-based policy
Error: Cannot assume IAM Role




│ Error: Invalid value for input variable
│ 
│   on .terraform/modules/eks_cluster.eks/node_groups.tf line 358, in module "eks_managed_node_group":
│  358:   tag_specifications                     = try(each.value.tag_specifications, var.eks_managed_node_group_defaults.tag_specifications, ["instance", "volume", "network-interface"])
│ 
│ The given value is not suitable for
│ module.eks_cluster.module.eks.module.eks_managed_node_group["default"].var.tag_specifications
│ declared at
│ .terraform/modules/eks_cluster.eks/modules/eks-managed-node-group/variables.tf:339,1-30:
│ element 0: string required.










```yml
 # module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0] will be created
  + resource "aws_launch_template" "this" {
      + arn                    = (known after apply)
      + default_version        = (known after apply)
      + description            = (known after apply)
      + id                     = (known after apply)
      + image_id               = "ami-03b4e6bf3aec4bb1e"
      + latest_version         = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "eks132-dev-ng-eks-node-group-"
      + tags                   = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "eks132-dev-ng"
          + "Project"     = "eks-cluster"
        }
      + tags_all               = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "eks132-dev-ng"
          + "Project"     = "eks-cluster"
        }
      + update_default_version = true
      + vpc_security_group_ids = [
          + "sg-0b7e9dac9bf730959",
        ]
      + block_device_mappings {
          + device_name = "/dev/xvda"
          + ebs {
              + delete_on_termination = "true"
              + encrypted             = "true"
              + iops                  = 3000
              + throughput            = 150
              + volume_size           = 100
              + volume_type           = "gp3"
            }
        }
      + metadata_options {
          + http_endpoint               = "enabled"
          + http_protocol_ipv6          = (known after apply)
          + http_put_response_hop_limit = 2
          + http_tokens                 = "required"
          + instance_metadata_tags      = (known after apply)
        }
      + monitoring {
          + enabled = true
        }
      + tag_specifications {
          + resource_type = "instance"
          + tags          = {
              + "ClusterName" = "eks132-lt-dev"
              + "ComponentID" = "14800"
              + "Environment" = "dev"
              + "ManagedBy"   = "terraform"
              + "Name"        = "eks132-dev-ng"
              + "Project"     = "eks-cluster"
            }
        }
      + tag_specifications {
          + resource_type = "network-interface"
          + tags          = {
              + "ClusterName" = "eks132-lt-dev"
              + "ComponentID" = "14800"
              + "Environment" = "dev"
              + "ManagedBy"   = "terraform"
              + "Name"        = "eks132-dev-ng"
              + "Project"     = "eks-cluster"
            }
        }
      + tag_specifications {
          + resource_type = "volume"
          + tags          = {
              + "ClusterName" = "eks132-lt-dev"
              + "ComponentID" = "14800"
              + "Environment" = "dev"
              + "ManagedBy"   = "terraform"
              + "Name"        = "eks132-dev-ng"
              + "Project"     = "eks-cluster"
            }
        }
    }
```














./values.yaml
  266:5     error    no new line character at the end of file  (new-line-at-end-of-file)
  266:1     error    trailing spaces  (trailing-spaces)
Cleaning up project directory and file based variables
00:01
ERROR: Job failed: exit code 1
