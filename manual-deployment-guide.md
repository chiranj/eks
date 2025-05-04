# Manual Deployment Guide for EKS Cluster

This guide explains how to deploy the EKS cluster and its add-ons using Terraform without GitLab CI/CD.

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- Terraform CLI (version 1.0.0 or newer) installed
- Basic understanding of Terraform and AWS EKS
- Access to an AWS account with permissions to create EKS clusters and IAM resources

## Setup Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd eks-module
```

### 2. Configure AWS Credentials

Ensure you have AWS credentials configured. You can do this in several ways:

```bash
# Option 1: Environment variables
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"

# Option 2: AWS CLI configuration
aws configure

# Option 3: Assume IAM role (recommended for production)
aws sts assume-role --role-arn "arn:aws:iam::123456789012:role/EksDeploymentRole" --role-session-name terraform-session
```

### 3. Create Your Configuration

Copy the example variables file and modify it for your environment:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to set your desired configuration. At minimum, you need to set:

```hcl
# Required variables
cluster_name   = "my-eks-cluster"
vpc_id         = "vpc-01234567890abcdef"
subnet_ids     = ["subnet-01234567890abcdef", "subnet-01234567890abcdef"]

# Select which add-ons to enable
enable_aws_load_balancer_controller = true
node_scaling_method                 = "karpenter"  # "karpenter", "cluster_autoscaler", or "none"
enable_keda                         = true
enable_external_dns                 = true
enable_prometheus                   = false

# Storage add-ons (EBS is enabled by default)
enable_ebs_csi_driver               = true
enable_efs_csi_driver               = false

# IMPORTANT: Disable GitLab pipeline triggering for manual deployment
trigger_gitlab_pipeline             = false

# Tags
tags = {
  Environment = "production"
  ManagedBy   = "terraform"
  Project     = "eks-cluster"
}
```

> **IMPORTANT**: Make sure to set `trigger_gitlab_pipeline = false` when deploying manually to avoid GitLab integration errors.

### 4. Initialize Terraform

Use a local backend for Terraform state:

```bash
# Create backend.tf for local state storage
cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

# Initialize Terraform
terraform init
```

### 5. Deploy the EKS Cluster

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply
```

Review the changes and type `yes` to proceed with the deployment.

## Deploying Kubernetes Add-ons

Unlike the GitLab CI/CD approach, when using manual deployment, you'll need to handle the Kubernetes add-on installation separately. This is because we're disabling the GitLab pipeline triggering (`trigger_gitlab_pipeline = false`), which would normally handle the Kubernetes add-on installation.

### Option 1: Manual Helm Chart Installation

After the EKS cluster is created, you'll need to install the add-ons yourself. First, configure kubectl:

```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

Then get the IAM role ARNs from Terraform output:

```bash
# Get all outputs
terraform output

# Or get specific role ARNs
LB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "Role not created")
KARPENTER_ROLE_ARN=$(terraform output -raw karpenter_role_arn 2>/dev/null || echo "Role not created")
EBS_CSI_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn 2>/dev/null || echo "Role not created")
# ... etc for each add-on you've enabled
```

Then install each add-on with Helm. For example:

```bash
# AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LB_ROLE_ARN

# EBS CSI Driver
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EBS_CSI_ROLE_ARN

# Karpenter (if node_scaling_method = "karpenter")
helm repo add karpenter https://charts.karpenter.sh
helm install karpenter karpenter/karpenter \
  --namespace kube-system \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$KARPENTER_ROLE_ARN \
  --set settings.aws.clusterName=<cluster-name>

# External DNS (if enabled)
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm install external-dns external-dns/external-dns \
  --namespace kube-system \
  --set provider=aws \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTERNAL_DNS_ROLE_ARN \
  --set domainFilters[0]=<your-domain>

# Other add-ons can be installed similarly based on your configuration
```

### Option 2: Use GitLab CI/CD for Add-ons Only

You can still use the GitLab CI/CD pipeline just for deploying the add-ons:

1. Extract the OIDC provider ARN and cluster details from the Terraform output
2. Manually trigger the GitLab pipeline with the appropriate CLUSTER_CONFIG payload

## Additional Configuration Options

### Custom IAM Roles

To use custom IAM roles for Terraform execution:

```bash
# Assume role and capture credentials
creds=$(aws sts assume-role --role-arn arn:aws:iam::123456789012:role/CustomEksRole --role-session-name terraform-session)

# Export credentials
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')
```

### Remote State Management

For production use, consider using a remote state backend:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Using Custom AMIs for Worker Nodes

By default, EKS uses the latest Amazon EKS-optimized AMI for worker nodes. If you need to use a custom AMI (for example, if you need specific software pre-installed or custom configurations), you can do this in two ways:

1. **Global AMI for all node groups**:
   ```hcl
   # Use this AMI for all node groups
   node_group_ami_id = "ami-0123456789abcdef0"
   ```

2. **Per node group AMI**:
   ```hcl
   eks_managed_node_groups = {
     default = {
       # ... other configurations ...
       ami_id = "ami-0123456789abcdef0"  # Specific AMI for this node group
     }
     second_group = {
       # ... other configurations ...
       ami_id = "ami-0abcdef1234567890"  # Different AMI for this node group
     }
   }
   ```

### How Custom AMI Support Works

Our solution implements custom AMI support using launch templates that are created automatically when you specify an AMI:

1. When you specify an `ami_id` either globally or for a specific node group, our module:
   - Creates a launch template with the specified AMI
   - Includes a properly configured bootstrap script that allows the nodes to join the EKS cluster
   - Configures security, networking, and other required settings
   - References this launch template in the EKS managed node group configuration

2. Additional configuration options:
   ```hcl
   eks_managed_node_groups = {
     custom_group = {
       ami_id = "ami-0123456789abcdef0"
       
       # Optional bootstrap script arguments 
       bootstrap_extra_args = "--use-max-pods false --container-runtime containerd"
       
       # Optional kubelet arguments
       kubelet_extra_args = "--node-labels=workload-type=cpu-optimized"
     }
   }
   ```

When using custom AMIs, ensure that:
- The AMI is compatible with EKS (contains the required bootstrap scripts)
- The AMI exists in the same region as your EKS cluster
- You have permissions to use the specified AMI
- The AMI has the AWS EKS bootstrap script installed at `/etc/eks/bootstrap.sh`

If you need to disable the automatic launch template creation for custom AMIs:
```hcl
create_launch_templates_for_custom_amis = false
```

## Common Issues and Solutions

1. **VPC and subnet validation errors**: Ensure your VPC subnets have the required tags for EKS:
   - Public subnets: `kubernetes.io/role/elb: 1`
   - Private subnets: `kubernetes.io/role/internal-elb: 1`

2. **IAM permission issues**: The user/role executing Terraform needs extensive IAM permissions. Consider using the AWS managed policy `AdministratorAccess` for testing, or create a custom policy with the minimum required permissions.

3. **Cluster creation timeout**: EKS cluster creation can take 15-20 minutes. If it times out, check the AWS console for the actual status.

4. **GitLab integration errors**: If you see errors related to the GitLab pipeline trigger, make sure you've set `trigger_gitlab_pipeline = false` in your terraform.tfvars file. The error might look like:
   ```
   Error: Error running command 'curl --request POST...': Process exited with status 1
   ```

5. **Custom AMI validation errors**: If you specified a custom AMI and encounter errors, verify that:
   - The AMI ID is valid and exists in your region
   - You have permissions to use the AMI
   - The AMI is compatible with EKS and has the required bootstrap script
   - The user-data script is executing correctly (check EC2 instance logs)
   
6. **Custom AMI nodes not joining the cluster**: If nodes with custom AMIs are being created but not joining the cluster:
   - Check that the bootstrap script is present at `/etc/eks/bootstrap.sh` in your AMI
   - Verify the user-data script is executing properly (check EC2 instance logs)
   - Ensure your custom AMI has all required EKS dependencies
   - Check that the nodes have network connectivity to the EKS control plane endpoint
   - If using a custom CNI, ensure it's properly configured in the launch template

## Cleaning Up

To destroy all resources:

```bash
terraform destroy
```

Review the resources to be destroyed and type `yes` to confirm. This will remove the EKS cluster and all associated resources.

## Switching Between GitLab CI/CD and Manual Deployment

If you've previously used GitLab CI/CD and want to switch to manual deployment, or vice versa, you'll need to be careful with the Terraform state.

For GitLab to manual:
1. Export the Terraform state from GitLab
2. Configure a local backend
3. Import the state file

For manual to GitLab:
1. Configure the GitLab backend in your pipeline
2. Upload your local state file

## Creating Helper Scripts

To make the manual deployment process easier, you can create scripts to automate parts of the workflow:

### 1. Terraform Deployment Script

Create a file named `deploy.sh`:

```bash
#!/bin/bash
set -e

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo "Error: terraform.tfvars file not found."
  echo "Please create this file based on terraform.tfvars.example."
  exit 1
fi

# Check if trigger_gitlab_pipeline is set to false
if ! grep -q "trigger_gitlab_pipeline *= *false" terraform.tfvars; then
  echo "Warning: It's recommended to set trigger_gitlab_pipeline = false for manual deployment."
  read -p "Do you want to continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Initialize Terraform
terraform init -backend-config=backend.tf || terraform init -reconfigure -backend-config=backend.tf

# Create plan
terraform plan -out=tfplan

# Apply if confirmed
read -p "Do you want to apply this plan? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  terraform apply "tfplan"
fi
```

### 2. Add-ons Installation Script

Create a file named `install-addons.sh`:

```bash
#!/bin/bash
set -e

# Get cluster name from terraform output
CLUSTER_NAME=$(terraform output -raw cluster_id)
REGION=$(terraform output -raw cluster_endpoint | sed 's/.*eks\.\(.*\)\.amazonaws\.com.*/\1/')

# Update kubeconfig
echo "Configuring kubectl to connect to cluster $CLUSTER_NAME in region $REGION..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Get IAM role ARNs
echo "Retrieving IAM role ARNs from Terraform output..."
LB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
KARPENTER_ROLE_ARN=$(terraform output -raw karpenter_role_arn 2>/dev/null || echo "")
EBS_CSI_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn 2>/dev/null || echo "")
EFS_CSI_ROLE_ARN=$(terraform output -raw efs_csi_driver_role_arn 2>/dev/null || echo "")
EXTERNAL_DNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn 2>/dev/null || echo "")
# Add other role ARNs as needed

# Install add-ons based on which IAM roles exist
# AWS Load Balancer Controller
if [ -n "$LB_ROLE_ARN" ] && [ "$LB_ROLE_ARN" != "" ]; then
  echo "Installing AWS Load Balancer Controller..."
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=true \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LB_ROLE_ARN
fi

# EBS CSI Driver
if [ -n "$EBS_CSI_ROLE_ARN" ] && [ "$EBS_CSI_ROLE_ARN" != "" ]; then
  echo "Installing EBS CSI Driver..."
  helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
  helm repo update
  helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
    --namespace kube-system \
    --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EBS_CSI_ROLE_ARN
fi

# Add installation for other add-ons here...
echo "Add-on installation complete!"
```

Make the scripts executable:

```bash
chmod +x deploy.sh install-addons.sh
```

You can then run them in sequence:

```bash
./deploy.sh
./install-addons.sh
```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform EKS Module Documentation](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Helm Documentation](https://helm.sh/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Amazon EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [Amazon EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [Karpenter](https://karpenter.sh/)