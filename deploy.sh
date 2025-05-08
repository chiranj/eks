#!/bin/bash
set -e

# Helper script for phased deployment of EKS cluster with custom AMIs
# This script handles the dependency cycle between EKS control plane and node groups

echo "Starting phased deployment of EKS cluster..."

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo "Error: terraform.tfvars file not found."
  echo "Please create this file based on terraform.tfvars.example."
  exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Phase 1: Deploy Control Plane Only
echo "Phase 1: Deploying EKS control plane..."
terraform apply -target=module.eks_cluster.module.eks.aws_eks_cluster.this[0] -auto-approve

# Get the actual resource addresses for launch templates and node groups
echo "Finding the actual resource addresses..."
TEMPLATES=$(terraform state list | grep 'aws_launch_template' | grep 'module.eks_cluster')
NODEGROUPS=$(terraform state list | grep 'aws_eks_node_group' | grep 'module.eks_cluster')

if [ -z "$TEMPLATES" ]; then
  # If resources don't exist yet in state, use more aggressive pattern matching
  echo "No launch templates found in state, using pattern targeting..."
  # Phase 2: Create Launch Templates with Complete Data
  echo "Phase 2: Creating launch templates with complete bootstrap data..."
  terraform apply -target='module.eks_cluster.module.eks' -target='module.eks_cluster.module.eks.module.eks_managed_node_group["default"]' -auto-approve
else
  # Phase 2: Create Launch Templates with Complete Data
  echo "Phase 2: Creating launch templates with complete bootstrap data..."
  for TEMPLATE in $TEMPLATES; do
    echo "Targeting template: $TEMPLATE"
    terraform apply -target="$TEMPLATE" -auto-approve
  done
fi

# Phase 3: Create Node Groups
echo "Phase 3: Creating EKS node groups..."
if [ -z "$NODEGROUPS" ]; then
  echo "No node groups found in state, using pattern targeting..."
  terraform apply -target='module.eks_cluster.module.eks.module.eks_managed_node_group["default"]' -auto-approve
else
  for NODEGROUP in $NODEGROUPS; do
    echo "Targeting node group: $NODEGROUP"
    terraform apply -target="$NODEGROUP" -auto-approve
  done
fi

# Phase 4: Deploy Everything Else (including EKS managed add-ons)
echo "Phase 4: Deploying remaining resources (including add-ons)..."
terraform apply -auto-approve

echo "Deployment complete!"
echo "The EBS CSI and EFS CSI drivers have been installed as EKS managed add-ons."
echo "To verify the deployment:"
echo "  kubectl get pods -n kube-system | grep csi"
echo "  kubectl get sc"  # To see the storage classes

# Output cluster information
echo "Getting cluster information..."
terraform output