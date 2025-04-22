#!/bin/bash
set -e

# Validate main Terraform module
echo "Validating main Terraform module..."
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# Validate Service Catalog Terraform product
echo "Validating Service Catalog Terraform product..."
cd sc-product-terraform
terraform fmt -check
terraform init -backend=false
terraform validate

# Validate the example configuration
echo "Validating example configuration..."
cd ../examples/complete
terraform fmt -check
terraform init -backend=false
terraform validate

echo "All validations passed!"