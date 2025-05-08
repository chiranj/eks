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

# Phase 2: Create Launch Templates with Complete Data
echo "Phase 2: Creating launch templates with complete bootstrap data..."
terraform apply -target='module.eks_cluster.module.eks.aws_launch_template.this' -auto-approve

# Phase 3: Create Node Groups
echo "Phase 3: Creating EKS node groups..."
terraform apply -target='module.eks_cluster.module.eks.aws_eks_node_group.this' -auto-approve

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