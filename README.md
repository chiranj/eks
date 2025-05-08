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
- hosts: docco_2
  gather_facts: yes
  become: yes
  remote_user: srv_ansible_usr
  vars:
    service_version: "2.2.1.616"
    ocr_version: "0.40.1.458"
    support_version: "0.20.15"
    docker_registry: "prod-cicm.uspto.gov:9998/techre/doccode"
    pull_images_only: false
    skip_image_pull: true
    deploy_nginx: false
    deploy_health: false
    deploy_ocr: false
    deploy_service: true
    deploy_logrotate: false
    containers: []
    docker_api_version: "1.41"  # Add this line

  pre_tasks:
    # First, ensure Docker service is running
    - name: Ensure Docker service is running
      service:
        name: docker
        state: started
        enabled: yes

    - name: Populate containers list based on deployment flags
      set_fact:
        containers: "{{ containers + [item] }}"
      when: item.deploy_flag|bool
      with_items:
        - name: doccode-nginx
          version: "{{ support_version }}"
          network_mode: "host"
          volumes: []
          deploy_flag: "{{ deploy_nginx }}"
        - name: doccode-health
          version: "{{ support_version }}"
          network_mode: "host"
          volumes: []
          deploy_flag: "{{ deploy_health }}"
        - name: doccode-ocr
          version: "{{ ocr_version }}"
          network_mode: "host"
          volumes: []
          deploy_flag: "{{ deploy_ocr }}"
        - name: doccode-service
          version: "{{ service_version }}"
          network_mode: "host"
          volumes:
            - /var/log/docker/:/app/logs/
          deploy_flag: "{{ deploy_service }}"
        - name: doccode-logrotate
          version: "{{ support_version }}"
          network_mode: "host"
          volumes:
            - /var/log/docker/:/var/log/docker/
          deploy_flag: "{{ deploy_logrotate }}"

  tasks:

    - name: Remove all exited containers
      shell: docker ps -a -q -f status=exited | xargs --no-run-if-empty docker rm
      ignore_errors: yes
      when:
        - not pull_images_only|bool

    - name: Pull Docker images
      docker_image:
        name: "{{ docker_registry }}/{{ item.name }}:{{ item.version }}"
        source: pull
        force_source: yes
      with_items: "{{ containers }}"
      when:
        - containers|length > 0
        - not skip_image_pull|bool

    - name: Stop running containers
      docker_container:
        name: "{{ item.name }}"
        state: stopped
        api_version: "{{ docker_api_version }}"
      with_items: "{{ containers }}"
      ignore_errors: yes
      when:
        - containers|length > 0
        - not pull_images_only|bool

    - name: Remove stopped containers
      docker_container:
        name: "{{ item.name }}"
        state: absent
        api_version: "{{ docker_api_version }}"
      with_items: "{{ containers }}"
      ignore_errors: yes
      when:
        - containers|length > 0
        - not pull_images_only|bool

    - name: Start new containers
      docker_container:
        name: "{{ item.name }}"
        image: "{{ docker_registry }}/{{ item.name }}:{{ item.version }}"
        env:
          client_id: "0oa4bnc5daPxies414h7"
          client_secret: "MTBb8LcZANAEIB8ENukXWRA1FVa4gn1VkGF9dB4Y"
          token_url: "https://auth.uspto.gov/oauth2/aus4qv50b0BRaFZMp4h7/v1/token"
        state: started
        restart_policy: unless-stopped
        network_mode: "{{ item.network_mode }}"
        volumes: "{{ item.volumes }}"
        api_version: "{{ docker_api_version }}"
      with_items: "{{ containers }}"
      when:
        - containers|length > 0
        - not pull_images_only|bool

    - name: Verify containers are running
      docker_container_info:
        name: "{{ item.name }}"
        api_version: "{{ docker_api_version }}"
      register: container_info
      with_items: "{{ containers }}"
      failed_when: not container_info.exists or container_info.container.State.Status != 'running'
      when:
        - containers|length > 0
        - not pull_images_only|bool
```

TASK [Stop running containers] **************************************************************************************************************************************************************************************************************
failed: [dav-doccodeqc-script-16.cld.uspto.gov] (item={'name': 'doccode-service', 'version': '2.2.1.616', 'network_mode': 'host', 'volumes': ['/var/log/docker/:/app/logs/'], 'deploy_flag': True}) => {"ansible_loop_var": "item", "changed": false, "item": {"deploy_flag": true, "name": "doccode-service", "network_mode": "host", "version": "2.2.1.616", "volumes": ["/var/log/docker/:/app/logs/"]}, "msg": "Error retrieving container list: 'http+docker'"}
...ignoring



```yml

# Cluster configuration
region         = "us-east-1"
cluster_name   = "eks132-lt-dev"
cluster_version = "1.32"

# VPC configuration (use existing VPC)
vpc_mode      = "existing"
vpc_id        = "vpc-0fdf8f6123bcee653"
subnet_ids    = ["subnet-06fbd21c8b18472d5", "subnet-00ec24404cb22eef3"]
control_plane_subnet_ids = ["subnet-0383101af50ccc089", "subnet-08c5702ac133f7990"]

create_cluster_iam_role = false
create_addon_roles = false
cluster_iam_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
create_node_iam_role = false
node_iam_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"
iam_admin_role_arn = "arn:aws:iam::583541782477:role/uspto-dev/aws-psb-lab-service-role-1"

create_launch_templates_for_custom_amis = true
service_ipv4_cidr = "172.20.0.0/16
cluster_ip_family = "ipv4"


# Node group configuration
eks_managed_node_groups = {
  default = {
    name = "eks132-dev-ng"
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    min_size     = 2
    max_size     = 5
    desired_size = 2
    labels = {
      Environment = "dev"
      Role        = "general"
    }
    ami_id = "ami-03b4e6bf3aec4bb1e"
    max_pods= "70"
    update_config = {
      max_unavailable = 1
    }
  }
}



# Access configuration - new in EKS module v20 (Optional)
 eks_access_entries = {
   admin-role = {
     principal_arn = "arn:aws:iam::583541782477:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_SsbAwsDevPSB_757bdd0a5303e68f"
     policy_associations = {
       admin = {
         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
         access_scope = {
           type = "cluster"
         }
       }
     }
   }
 }

# Add-ons configuration
enable_aws_load_balancer_controller = true
node_scaling_method                 = "karpenter"  # "karpenter", "cluster_autoscaler", or "none"
enable_keda                         = true
enable_external_dns                 = true
enable_prometheus                   = true
enable_secrets_manager              = true
enable_cert_manager                 = true
enable_nginx_ingress                = true
enable_adot                         = true
enable_fluent_bit                   = true


enable_ebs_csi_driver               = true
enable_efs_csi_driver               = true

# External DNS configuration (if enabled)
external_dns_hosted_zone_source     = "existing"
external_dns_existing_hosted_zone_id = "Z00653782CEB2BPWF3550"  


# GitLab integration (for Kubernetes components installation)
trigger_gitlab_pipeline   = false

component_id = 14800
# Tags
tags = {
  Environment = "dev"
  ManagedBy   = "terraform"
  Project     = "eks-cluster"
  }
```
