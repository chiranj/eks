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
cluster_arn = "arn:aws:eks:us-east-1:583541782477:cluster/eks132-lt-dev"
cluster_autoscaler_role_arn = ""
cluster_certificate_authority_data = <sensitive>
cluster_endpoint = "https://D0EDE06DAD57F0495A8D0F7684C58A1A.gr7.us-east-1.eks.amazonaws.com"
cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A"
gitlab_deployment_role_arn = ""
gitlab_integration_env_file_path = ""
gitlab_integration_json_file_path = ""
gitlab_integration_status = "disabled"
oidc_provider_arn = "arn:aws:iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A"
vpc_id = "vpc-0fdf8f6123bcee653"
$ terraform apply -target=module.eks_cluster.module.eks -target='module.eks_cluster.module.eks.module.eks_managed_node_group["default"]' -auto-approve
module.eks_cluster.module.eks.module.kms.data.aws_partition.current[0]: Reading...
module.eks_cluster.aws_iam_policy.launch_template_access: Refreshing state... [id=arn:aws:iam::583541782477:policy/eks132-lt-dev-ec2-full-access]
module.eks_cluster.module.eks.data.aws_partition.current[0]: Reading...
module.eks_cluster.module.eks.data.aws_caller_identity.current[0]: Reading...
module.eks_cluster.module.eks.module.kms.data.aws_caller_identity.current[0]: Reading...
data.aws_caller_identity.current: Reading...
module.eks_cluster.module.eks.aws_cloudwatch_log_group.this[0]: Refreshing state... [id=/aws/eks/eks132-lt-dev/cluster]
module.eks_cluster.module.eks.module.kms.data.aws_caller_identity.current[0]: Read complete after 0s [id=583541782477]
module.eks_cluster.module.eks.module.kms.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.eks_cluster.module.eks.aws_security_group.cluster[0]: Refreshing state... [id=sg-0417d560774984e04]
module.eks_cluster.module.eks.data.aws_partition.current[0]: Read complete after 0s [id=aws]
data.aws_caller_identity.current: Read complete after 0s [id=583541782477]
module.eks_cluster.module.eks.data.aws_caller_identity.current[0]: Read complete after 0s [id=583541782477]
module.eks_cluster.module.eks.aws_security_group.node[0]: Refreshing state... [id=sg-0b7e9dac9bf730959]
module.eks_cluster.module.eks.data.aws_iam_session_context.current[0]: Reading...
module.eks_cluster.module.eks.data.aws_iam_session_context.current[0]: Read complete after 0s [id=arn:aws:sts::583541782477:assumed-role/uacs-gitlab-runner-role-1/i-0da1b3e8ffe8e22b7]
module.eks_cluster.module.eks.module.kms.data.aws_iam_policy_document.this[0]: Reading...
module.eks_cluster.module.eks.module.kms.data.aws_iam_policy_document.this[0]: Read complete after 0s [id=611408724]
module.eks_cluster.module.eks.module.kms.aws_kms_key.this[0]: Refreshing state... [id=b460cab3-3cfb-48e9-973c-a4d38ac63067]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Refreshing state... [id=sgrule-2345060567]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Refreshing state... [id=sgrule-1373148000]
module.eks_cluster.module.eks.aws_security_group_rule.node["egress_all"]: Refreshing state... [id=sgrule-1406730188]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Refreshing state... [id=sgrule-3626765087]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Refreshing state... [id=sgrule-161082418]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Refreshing state... [id=sgrule-3762967293]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Refreshing state... [id=sgrule-2560292086]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Refreshing state... [id=sgrule-4016569116]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Refreshing state... [id=sgrule-2726907860]
module.eks_cluster.module.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Refreshing state... [id=sgrule-3118928359]
module.eks_cluster.module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Refreshing state... [id=sgrule-1142288658]
module.eks_cluster.module.eks.module.kms.aws_kms_alias.this["cluster"]: Refreshing state... [id=alias/eks/eks132-lt-dev]
module.eks_cluster.module.eks.aws_eks_cluster.this[0]: Refreshing state... [id=eks132-lt-dev]
module.eks_cluster.module.eks.time_sleep.this[0]: Refreshing state... [id=2025-05-08T07:01:39Z]
module.eks_cluster.module.eks.aws_ec2_tag.cluster_primary_security_group["Project"]: Refreshing state... [id=sg-0b85bae786f217e8e,Project]
module.eks_cluster.module.eks.data.tls_certificate.this[0]: Reading...
module.eks_cluster.module.eks.aws_eks_access_entry.this["admin-role"]: Refreshing state... [id=eks132-lt-dev:arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f]
module.eks_cluster.module.eks.aws_ec2_tag.cluster_primary_security_group["ManagedBy"]: Refreshing state... [id=sg-0b85bae786f217e8e,ManagedBy]
module.eks_cluster.module.eks.aws_ec2_tag.cluster_primary_security_group["ComponentID"]: Refreshing state... [id=sg-0b85bae786f217e8e,ComponentID]
module.eks_cluster.module.eks.aws_ec2_tag.cluster_primary_security_group["ClusterName"]: Refreshing state... [id=sg-0b85bae786f217e8e,ClusterName]
module.eks_cluster.module.eks.aws_ec2_tag.cluster_primary_security_group["Environment"]: Refreshing state... [id=sg-0b85bae786f217e8e,Environment]
module.efs_csi_driver_iam[0].data.aws_iam_policy_document.efs_csi: Reading...
module.ebs_csi_driver_iam[0].data.aws_iam_policy_document.ebs_csi: Reading...
module.ebs_csi_driver_iam[0].data.aws_iam_policy_document.ebs_csi: Read complete after 0s [id=2052965142]
module.efs_csi_driver_iam[0].data.aws_iam_policy_document.efs_csi: Read complete after 0s [id=3829662168]
module.eks_cluster.module.eks.data.tls_certificate.this[0]: Read complete after 0s [id=922877a0975ad078a65b8ff11ebc47b8311945c7]
module.eks_cluster.module.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Refreshing state... [id=arn:aws:iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A]
module.eks_cluster.module.eks.aws_eks_access_policy_association.this["admin-role_admin"]: Refreshing state... [id=eks132-lt-dev#arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy]
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].data.aws_partition.current: Reading...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].data.aws_partition.current: Read complete after 0s [id=aws]
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].data.aws_caller_identity.current: Reading...
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["kube-proxy"]: Reading...
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["coredns"]: Reading...
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["aws-efs-csi-driver"]: Reading...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].module.user_data.null_resource.validate_cluster_service_cidr: Refreshing state... [id=4098913671023706518]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["vpc-cni"]: Reading...
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Reading...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].data.aws_caller_identity.current: Read complete after 0s [id=583541782477]
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0]: Refreshing state... [id=lt-034d30ba8f8bdd51f]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["aws-efs-csi-driver"]: Read complete after 0s [id=aws-efs-csi-driver]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["vpc-cni"]: Read complete after 0s [id=vpc-cni]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["kube-proxy"]: Read complete after 0s [id=kube-proxy]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Read complete after 0s [id=aws-ebs-csi-driver]
module.eks_cluster.module.eks.data.aws_eks_addon_version.this["coredns"]: Read complete after 0s [id=coredns]
Note: Objects have changed outside of Terraform
Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:
  # module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0] has been deleted
  - resource "aws_launch_template" "this" {
      - arn                     = "arn:aws:ec2:us-east-1:583541782477:launch-template/lt-034d30ba8f8bdd51f" -> null
      - default_version         = 1 -> null
      - id                      = "lt-034d30ba8f8bdd51f" -> null
      - latest_version          = 1 -> null
      - name                    = "eks132-dev-ng-eks-node-group-20250508070139981100000001" -> null
        tags                    = {
            "ClusterName" = "eks132-lt-dev"
            "ComponentID" = "14800"
            "Environment" = "dev"
            "ManagedBy"   = "terraform"
            "Name"        = "eks132-dev-ng"
            "Project"     = "eks-cluster"
        }
        # (9 unchanged attributes hidden)
        # (6 unchanged blocks hidden)
    }
Unless you have made equivalent changes to your configuration, or ignored the
relevant attributes using ignore_changes, the following plan may include
actions to undo or respond to these changes.
─────────────────────────────────────────────────────────────────────────────
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
Terraform will perform the following actions:
  # module.ebs_csi_driver_iam[0].aws_iam_role.ebs_csi will be created
  + resource "aws_iam_role" "ebs_csi" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRoleWithWebIdentity"
                      + Condition = {
                          + StringEquals = {
                              + "iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
                            }
                        }
                      + Effect    = "Allow"
                      + Principal = {
                          + Federated = "arn:aws:iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks132-lt-dev-ebs-csi-driver"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all              = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + unique_id             = (known after apply)
    }
  # module.efs_csi_driver_iam[0].aws_iam_role.efs_csi will be created
  + resource "aws_iam_role" "efs_csi" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRoleWithWebIdentity"
                      + Condition = {
                          + StringEquals = {
                              + "iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
                            }
                        }
                      + Effect    = "Allow"
                      + Principal = {
                          + Federated = "arn:aws:iam::583541782477:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/D0EDE06DAD57F0495A8D0F7684C58A1A"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks132-lt-dev-efs-csi-driver"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all              = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + unique_id             = (known after apply)
    }
  # module.eks_cluster.module.eks.aws_eks_addon.this["aws-ebs-csi-driver"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "aws-ebs-csi-driver"
      + addon_version               = "v1.42.0-eksbuild.1"
      + arn                         = (known after apply)
      + cluster_name                = "eks132-lt-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + resolve_conflicts_on_create = "OVERWRITE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + service_account_role_arn    = (known after apply)
      + tags                        = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all                    = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + timeouts {}
    }
  # module.eks_cluster.module.eks.aws_eks_addon.this["aws-efs-csi-driver"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "aws-efs-csi-driver"
      + addon_version               = "v2.1.7-eksbuild.1"
      + arn                         = (known after apply)
      + cluster_name                = "eks132-lt-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + resolve_conflicts_on_create = "OVERWRITE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + service_account_role_arn    = (known after apply)
      + tags                        = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all                    = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + timeouts {}
    }
  # module.eks_cluster.module.eks.aws_eks_addon.this["coredns"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "coredns"
      + addon_version               = "v1.11.4-eksbuild.10"
      + arn                         = (known after apply)
      + cluster_name                = "eks132-lt-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + resolve_conflicts_on_create = "OVERWRITE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all                    = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + timeouts {}
    }
  # module.eks_cluster.module.eks.aws_eks_addon.this["kube-proxy"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "kube-proxy"
      + addon_version               = "v1.32.3-eksbuild.7"
      + arn                         = (known after apply)
      + cluster_name                = "eks132-lt-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + resolve_conflicts_on_create = "OVERWRITE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all                    = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + timeouts {}
    }
  # module.eks_cluster.module.eks.aws_eks_addon.this["vpc-cni"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "vpc-cni"
      + addon_version               = "v1.19.5-eksbuild.1"
      + arn                         = (known after apply)
      + cluster_name                = "eks132-lt-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + resolve_conflicts_on_create = "OVERWRITE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + tags_all                    = {
          + "ClusterName" = "eks132-lt-dev"
          + "ComponentID" = "14800"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "eks-cluster"
        }
      + timeouts {}
    }
  # module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0] will be created
  + resource "aws_eks_node_group" "this" {
      + ami_type               = (known after apply)
      + arn                    = (known after apply)
      + capacity_type          = "ON_DEMAND"
      + cluster_name           = "eks132-lt-dev"
      + disk_size              = (known after apply)
      + id                     = (known after apply)
      + instance_types         = [
          + "m5.large",
        ]
      + labels                 = {
          + "Environment" = "dev"
          + "Role"        = "general"
        }
      + node_group_name        = (known after apply)
      + node_group_name_prefix = "eks132-dev-ng-"
      + node_role_arn          = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
      + release_version        = (known after apply)
      + resources              = (known after apply)
      + status                 = (known after apply)
      + subnet_ids             = [
          + "subnet-00ec24404cb22eef3",
          + "subnet-06fbd21c8b18472d5",
        ]
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
      + version                = (known after apply)
      + launch_template {
          + id      = (known after apply)
          + name    = (known after apply)
          + version = "$Latest"
        }
      + scaling_config {
          + desired_size = 2
          + max_size     = 5
          + min_size     = 2
        }
      + timeouts {}
      + update_config {
          + max_unavailable_percentage = 33
        }
    }
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
Plan: 9 to add, 0 to change, 0 to destroy.
Changes to Outputs:
  + cluster_addons                     = {
      + aws-ebs-csi-driver = {
          + addon_name                  = "aws-ebs-csi-driver"
          + addon_version               = "v1.42.0-eksbuild.1"
          + arn                         = (known after apply)
          + cluster_name                = "eks132-lt-dev"
          + configuration_values        = (known after apply)
          + created_at                  = (known after apply)
          + id                          = (known after apply)
          + modified_at                 = (known after apply)
          + pod_identity_association    = []
          + preserve                    = true
          + resolve_conflicts           = null
          + resolve_conflicts_on_create = "OVERWRITE"
          + resolve_conflicts_on_update = "OVERWRITE"
          + service_account_role_arn    = (known after apply)
          + tags                        = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + tags_all                    = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + timeouts                    = {
              + create = null
              + delete = null
              + update = null
            }
        }
      + aws-efs-csi-driver = {
          + addon_name                  = "aws-efs-csi-driver"
          + addon_version               = "v2.1.7-eksbuild.1"
          + arn                         = (known after apply)
          + cluster_name                = "eks132-lt-dev"
          + configuration_values        = (known after apply)
          + created_at                  = (known after apply)
          + id                          = (known after apply)
          + modified_at                 = (known after apply)
          + pod_identity_association    = []
          + preserve                    = true
          + resolve_conflicts           = null
          + resolve_conflicts_on_create = "OVERWRITE"
          + resolve_conflicts_on_update = "OVERWRITE"
          + service_account_role_arn    = (known after apply)
          + tags                        = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + tags_all                    = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + timeouts                    = {
              + create = null
              + delete = null
              + update = null
            }
        }
      + coredns            = {
          + addon_name                  = "coredns"
          + addon_version               = "v1.11.4-eksbuild.10"
          + arn                         = (known after apply)
          + cluster_name                = "eks132-lt-dev"
          + configuration_values        = (known after apply)
          + created_at                  = (known after apply)
          + id                          = (known after apply)
          + modified_at                 = (known after apply)
          + pod_identity_association    = []
          + preserve                    = true
          + resolve_conflicts           = null
          + resolve_conflicts_on_create = "OVERWRITE"
          + resolve_conflicts_on_update = "OVERWRITE"
          + service_account_role_arn    = null
          + tags                        = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + tags_all                    = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + timeouts                    = {
              + create = null
              + delete = null
              + update = null
            }
        }
      + kube-proxy         = {
          + addon_name                  = "kube-proxy"
          + addon_version               = "v1.32.3-eksbuild.7"
          + arn                         = (known after apply)
          + cluster_name                = "eks132-lt-dev"
          + configuration_values        = (known after apply)
          + created_at                  = (known after apply)
          + id                          = (known after apply)
          + modified_at                 = (known after apply)
          + pod_identity_association    = []
          + preserve                    = true
          + resolve_conflicts           = null
          + resolve_conflicts_on_create = "OVERWRITE"
          + resolve_conflicts_on_update = "OVERWRITE"
          + service_account_role_arn    = null
          + tags                        = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + tags_all                    = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + timeouts                    = {
              + create = null
              + delete = null
              + update = null
            }
        }
      + vpc-cni            = {
          + addon_name                  = "vpc-cni"
          + addon_version               = "v1.19.5-eksbuild.1"
          + arn                         = (known after apply)
          + cluster_name                = "eks132-lt-dev"
          + configuration_values        = (known after apply)
          + created_at                  = (known after apply)
          + id                          = (known after apply)
          + modified_at                 = (known after apply)
          + pod_identity_association    = []
          + preserve                    = true
          + resolve_conflicts           = null
          + resolve_conflicts_on_create = "OVERWRITE"
          + resolve_conflicts_on_update = "OVERWRITE"
          + service_account_role_arn    = null
          + tags                        = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + tags_all                    = {
              + ClusterName = "eks132-lt-dev"
              + ComponentID = "14800"
              + Environment = "dev"
              + ManagedBy   = "terraform"
              + Project     = "eks-cluster"
            }
          + timeouts                    = {
              + create = null
              + delete = null
              + update = null
            }
        }
    }
  + ebs_csi_driver_role_arn            = (known after apply)
  + efs_csi_driver_role_arn            = (known after apply)
  + eks_managed_node_groups            = {
      + default = {
          + autoscaling_group_schedule_arns    = {}
          + iam_role_arn                       = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
          + iam_role_name                      = null
          + iam_role_unique_id                 = null
          + launch_template_arn                = (known after apply)
          + launch_template_id                 = (known after apply)
          + launch_template_latest_version     = (known after apply)
          + launch_template_name               = (known after apply)
          + node_group_arn                     = (known after apply)
          + node_group_autoscaling_group_names = (known after apply)
          + node_group_id                      = (known after apply)
          + node_group_labels                  = {
              + Environment = "dev"
              + Role        = "general"
            }
          + node_group_resources               = (known after apply)
          + node_group_status                  = (known after apply)
          + node_group_taints                  = []
          + platform                           = "linux"
        }
    }
module.efs_csi_driver_iam[0].aws_iam_role.efs_csi: Creating...
module.ebs_csi_driver_iam[0].aws_iam_role.ebs_csi: Creating...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0]: Creating...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0]: Creation complete after 6s [id=lt-00ddfd26c2382db22]
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Creating...
module.eks_cluster.module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [10s elapsed]

```

