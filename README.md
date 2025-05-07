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




 "DecodedMessage": "{\"allowed\":false,\"explicitDeny\":true,\"matchedStatements\":{\"items\":[{\"statementId\":\"DenyWithNoCompTag\",\"effect\":\"DENY\",\"principals\":{\"items\":[{\"value\":\"AROAYPXOM67G7A6BYFKN4:i-0da1b3e8ffe8e22b7\"}]},\"principalGroups\":{\"items\":[]},\"actions\":{\"items\":[{\"value\":\"ec2:RunInstances\"},{\"value\":\"ec2:CreateVolume\"}]},\"resources\":{\"items\":[{\"value\":\"arn:aws:ec2:*:*:instance/*\"},{\"value\":\"arn:aws:ec2:*:*:volume/*\"}]},\"conditions\":{\"items\":[{\"key\":\"aws:RequestTag/ComponentID\",\"values\":{\"items\":[{\"value\":\"true\"}]}},{\"key\":\"aws:PrincipalAccount\",\"values\":{\"items\":[{\"value\":\"108673741149\"},{\"value\":\"437457476573\"}]}},{\"key\":\"aws:PrincipalArn\",\"values\":{\"items\":[{\"value\":\"arn:aws:iam::*:role/uspto-ssb/SCLaunch-EKSProduct\"}]}}]}}]},\"failures\":{\"items\":[]},\"context\":{\"principal\":{\"id\":\"AROAYPXOM67G7A6BYFKN4:i-0da1b3e8ffe8e22b7\",\"arn\":\"arn:aws:sts::583541782477:assumed-role/uacs-gitlab-runner-role-1/i-0da1b3e8ffe8e22b7\"},\"action\":\"RunInstances\",\"resource\":\"arn:aws:ec2:us-east-1:583541782477:instance/*\",\"conditions\":{\"items\":[{\"key\":\"ec2:AvailabilityZoneId\",\"values\":{\"items\":[{\"value\":\"use1-az4\"}]}},{\"key\":\"ec2:MetadataHttpPutResponseHopLimit\",\"values\":{\"items\":[{\"value\":\"2\"}]}},{\"key\":\"ec2:InstanceMarketType\",\"values\":{\"items\":[{\"value\":\"on-demand\"}]}},{\"key\":\"aws:Resource\",\"values\":{\"items\":[{\"value\":\"instance/*\"}]}},{\"key\":\"aws:Account\",\"values\":{\"items\":[{\"value\":\"583541782477\"}]}},{\"key\":\"ec2:AvailabilityZone\",\"values\":{\"items\":[{\"value\":\"us-east-1b\"}]}},{\"key\":\"ec2:ebsOptimized\",\"values\":{\"items\":[{\"value\":\"false\"}]}},{\"key\":\"ec2:InstanceBandwidthWeighting\",\"values\":{\"items\":[{\"value\":\"default\"}]}},{\"key\":\"ec2:IsLaunchTemplateResource\",\"values\":{\"items\":[{\"value\":\"true\"}]}},{\"key\":\"ec2:InstanceType\",\"values\":{\"items\":[{\"value\":\"m5.large\"}]}},{\"key\":\"ec2:RootDeviceType\",\"values\":{\"items\":[{\"value\":\"ebs\"}]}},{\"key\":\"aws:Region\",\"values\":{\"items\":[{\"value\":\"us-east-1\"}]}},{\"key\":\"ec2:MetadataHttpEndpoint\",\"values\":{\"items\":[{\"value\":\"enabled\"}]}},{\"key\":\"ec2:InstanceMetadataTags\",\"values\":{\"items\":[{\"value\":\"disabled\"}]}},{\"key\":\"aws:Service\",\"values\":{\"items\":[{\"value\":\"ec2\"}]}},{\"key\":\"ec2:InstanceID\",\"values\":{\"items\":[{\"value\":\"*\"}]}},{\"key\":\"ec2:MetadataHttpTokens\",\"values\":{\"items\":[{\"value\":\"required\"}]}},{\"key\":\"aws:ResourceBeingCreated\",\"values\":{\"items\":[{\"value\":\"true\"}]}},{\"key\":\"aws:Type\",\"values\":{\"items\":[{\"value\":\"instance\"}]}},{\"key\":\"ec2:Tenancy\",\"values\":{\"items\":[{\"value\":\"default\"}]}},{\"key\":\"ec2:Region\",\"values\":{\"items\":[{\"value\":\"us-east-1\"}]}},{\"key\":\"aws:ARN\",\"values\":{\"items\":[{\"value\":\"arn:aws:ec2:us-east-1:583541782477:instance/*\"}]}},{\"key\":\"ec2:LaunchTemplate\",\"values\":{\"items\":[{\"value\":\"arn:aws:ec2:us-east-1:583541782477:launch-template/lt-0fb021b38b01c7640\"}]}}]}}}"
