# GitLab CI/CD Integration Guide

This guide explains how to use the EKS module with GitLab CI/CD for automated deployment.

## Prerequisites

- GitLab account/project with CI/CD capabilities
- AWS credentials with sufficient permissions to create EKS clusters
- Basic familiarity with GitLab CI/CD and Terraform

## Setup Options

### Option 1: Include Our Pipeline (Recommended)

This approach allows you to include our predefined pipeline in your own GitLab repository.

1. In your repository, create a `.gitlab-ci.yml` file with:

```yaml
include:
  - project: 'your-org/eks-module'
    ref: main
    file: '.gitlab-ci.yml'

variables:
  # Required variables
  CLUSTER_NAME: "my-eks-cluster"
  VPC_ID: "vpc-12345"
  SUBNET_IDS: '["subnet-123", "subnet-456", "subnet-789"]'
  CONTROL_PLANE_SUBNET_IDS: '["subnet-123", "subnet-456", "subnet-789"]'
  
  # IAM role to assume (required for deployment permissions)
  AWS_ROLE_TO_ASSUME: "arn:aws:iam::123456789012:role/MyCustomEksDeploymentRole"
  
  # Optional add-ons (enable only what you need)
  ENABLE_AWS_LOAD_BALANCER_CONTROLLER: "true"
  NODE_SCALING_METHOD: "karpenter"  # Options: karpenter, cluster_autoscaler, none
  ENABLE_KEDA: "true"
  ENABLE_EXTERNAL_DNS: "true"
  ENABLE_PROMETHEUS: "false"
  ENABLE_SECRETS_MANAGER: "false"
  ENABLE_CERT_MANAGER: "false"
  ENABLE_NGINX_INGRESS: "false"
  ENABLE_ADOT: "false"
  ENABLE_FLUENT_BIT: "false"
  
  # For External DNS (if enabled)
  EXTERNAL_DNS_HOSTED_ZONE_SOURCE: "existing"
  EXTERNAL_DNS_EXISTING_HOSTED_ZONE_ID: "Z123456789ABCDEFGHI"
  
  # For GitLab pipeline integration (optional)
  GITLAB_TOKEN: $GITLAB_TOKEN  # Secret variable
  GITLAB_PROJECT_ID: "12345678"
```

2. Set up the following CI/CD variables in your GitLab project settings:
   - `AWS_ROLE_TO_ASSUME` - ARN of the IAM role with permission to create resources
   - `AWS_DEFAULT_REGION` - AWS region to deploy in
   - `GITLAB_TOKEN` (if using GitLab pipeline integration)
   
   Note: Your GitLab runner must have instance role permissions to assume the specified role

3. Run the pipeline to deploy your EKS cluster.

### How Add-ons Work

The pipeline automatically:
1. Converts your CI/CD variables to a Terraform variables file
2. Only creates AWS resources for add-ons that you've enabled
3. Uses GitLab-managed state with a cluster-specific state file path

### Role-Based Access Control

The pipeline uses AWS role assumption for permissions:

1. **How it works**:
   - Your GitLab runner uses its instance role to assume the role specified in `AWS_ROLE_TO_ASSUME`
   - All AWS operations are performed using the permissions of the assumed role
   - This follows the least privilege principle

2. **Setting up your role**:
   - Create a custom IAM role in your AWS account with the necessary permissions
   - Add a trust relationship allowing your GitLab runner's role/instance profile to assume it
   - Specify this role ARN in one of two ways:
     - Set as `AWS_ROLE_TO_ASSUME` in your GitLab CI/CD variables (recommended)
     - Set as `gitlab_aws_role_arn` in your terraform.tfvars file

3. **Required permissions**:
   - The role must have permissions to create all the AWS resources needed for your selected add-ons
   - At minimum: EKS, IAM, EC2, and VPC permissions
   - Additional permissions based on which add-ons you enable

### Option 2: Use terraform.tfvars

1. Copy our module into your repository
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and modify as needed
3. Set up AWS credentials as CI/CD variables
4. Use our `.gitlab-ci.yml` file or create your own

## Available Configuration Options

All variables defined in `variables.tf` can be configured either:
- As GitLab CI/CD variables
- In your terraform.tfvars file

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| cluster_name | Name of the EKS cluster | "production-eks" |
| vpc_id | ID of your existing VPC | "vpc-01234567890abcdef" |
| subnet_ids | List of subnet IDs for nodes | ["subnet-123", "subnet-456"] |
| node_scaling_method | Scaling approach to use | "karpenter" |
| enable_* | Boolean flags for each add-on | true/false |

## Pipeline Stages

The included GitLab CI/CD pipeline has the following stages:
1. **validate** - Validates Terraform configuration
2. **plan** - Creates Terraform plan
3. **apply** - Applies the plan (manual trigger)
4. **destroy** - Destroys resources (manual trigger)

## Customizing the Pipeline

You can override any job or add additional jobs by defining them in your own `.gitlab-ci.yml` file after the include statement.

### Custom IAM Role Configuration

You have two options to specify a custom IAM role for deployment:

1. **Via GitLab CI/CD Variable (Recommended)**:
   ```yaml
   variables:
     AWS_ROLE_TO_ASSUME: "arn:aws:iam::123456789012:role/MyCustomEksDeploymentRole"
   ```

2. **Via terraform.tfvars**:
   ```hcl
   gitlab_aws_role_arn = "arn:aws:iam::123456789012:role/MyCustomEksDeploymentRole"
   ```

The pipeline will:
1. First check if a custom role is specified in terraform.tfvars (if the file exists)
2. Fall back to the AWS_ROLE_TO_ASSUME environment variable if no custom role is found in tfvars
3. Use the role to assume temporary AWS credentials for deployment
4. Pass the role ARN to child pipelines in the CLUSTER_CONFIG payload

This approach gives you flexibility to manage deployment permissions while keeping your configuration clean.

### In Child Pipelines

If your organization has multiple GitLab repositories that deploy different parts of the infrastructure,
you can extract and use the custom role from the CLUSTER_CONFIG payload:

```yaml
before_script:
  - |
    # Extract custom AWS role from CLUSTER_CONFIG if provided
    if [ ! -z "$CLUSTER_CONFIG" ]; then
      CUSTOM_ROLE=$(echo $CLUSTER_CONFIG | jq -r '.deployment.aws_role_arn // empty')
      if [ ! -z "$CUSTOM_ROLE" ] && [ "$CUSTOM_ROLE" != "null" ]; then
        echo "Using custom AWS role from CLUSTER_CONFIG: $CUSTOM_ROLE"
        AWS_ROLE_TO_ASSUME=$CUSTOM_ROLE
      fi
    fi
    
    # Assume the AWS role
    CREDENTIALS=$(aws sts assume-role --role-arn ${AWS_ROLE_TO_ASSUME} --role-session-name gitlab-ci-${CI_JOB_ID})
    # ... Rest of your AWS credential setup
```

## Troubleshooting

### Common Issues

1. **Missing AWS credentials**: Ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set
2. **Permission errors**: Check IAM permissions for the AWS user
3. **VPC/subnet errors**: Verify that VPC and subnet IDs are correct

### Getting Help

If you encounter issues, please:
1. Check the pipeline logs for specific error messages
2. Review our [FAQ](./faq.md)
3. Open an issue in the repository with details about your configuration