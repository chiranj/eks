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

Getting the thumbprint of the gitlab

```bash
openssl s_client -servername gitlab.com -showcerts -connect gitlab.com:443 < /dev/null 2>/dev/null | 
sed -n '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | 
awk 'BEGIN {c=0;} /BEGIN CERT/{c++} { if(c==3) print $0; }' | 
openssl x509 -fingerprint -sha1 -noout | 
sed 's/SHA1 Fingerprint=//g' | 
tr -d ':'
```


ADOT (AWS Distro for OpenTelemetry)
https://aws-observability.github.io/aws-otel-helm-charts

AWS Load Balancer Controller
https://aws.github.io/eks-charts

cert-manager
https://charts.jetstack.io

cluster-autoscaler
https://kubernetes.github.io/autoscaler

EBS CSI Driver
https://kubernetes-sigs.github.io/aws-ebs-csi-driver

EFS CSI Driver
https://kubernetes-sigs.github.io/aws-efs-csi-driver

external-dns
https://kubernetes-sigs.github.io/external-dns

fluent-bit
https://fluent.github.io/helm-charts

karpenter
https://charts.karpenter.sh

keda
https://kedacore.github.io/charts

nginx-ingress-controller
https://kubernetes.github.io/ingress-nginx

prometheus
https://prometheus-community.github.io/helm-charts

AWS Secrets & Configuration Provider (AWS Secrets Manager CSI Driver)
https://aws.github.io/secrets-store-csi-driver-provider-aws


   assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
     67    tags               = var.tags
     68  }
     69
     70    # Add managed policies
     71    managed_policy_arns = concat(
     72      var.managed_policy_arns,
     73      var.create_eks_access_policy ? ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"] : []
     74    )
     70  # Attach managed policies
     71  resource "aws_iam_role_policy_attachment" "managed_policies" {
     72    count      = length(var.managed_policy_arns)
     73    role       = aws_iam_role.gitlab_deployment_role.name
     74    policy_arn = var.managed_policy_arns[count.index]
     75  }
     76
     77    tags = var.tags
     77  # Attach EKS cluster policy if enabled
     78  resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
     79    count      = var.create_eks_access_policy ? 1 : 0
     80    role       = aws_iam_role.gitlab_deployment_role.name
     81    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
     82  }


