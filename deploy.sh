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

# Check if backend.tf exists, create a local one if not
if [ ! -f "backend.tf" ]; then
  echo "Creating a local backend configuration..."
  cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init || terraform init -reconfigure

# Create plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply if confirmed
read -p "Do you want to apply this plan? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Applying Terraform plan..."
  terraform apply "tfplan"
  echo "Deployment complete!"
else
  echo "Deployment cancelled."
fi