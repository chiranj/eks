# EKS Cluster with Add-ons - Service Catalog Terraform Product

This directory contains the AWS Service Catalog Terraform product configuration for deploying EKS clusters with optional add-ons.

## Terraform Reference Engine

This product is standardized on the AWS Service Catalog Terraform Reference Engine. The Terraform Reference Engine enables native Terraform support in AWS Service Catalog, allowing you to provision EKS clusters with Terraform while benefiting from Service Catalog's governance features.

## VPC Creation Capability

Although most users will have an existing VPC, this product includes the capability to optionally create a new VPC using the Terraform AWS VPC module. This is implemented with conditional logic in the Terraform code, allowing users to select whether to use an existing VPC or create a new one.

## Files

- `manifest.yaml` - Service Catalog Terraform product manifest that defines parameters, outputs, and dependencies
- `main.tf` - Main Terraform configuration that calls the parent EKS module with parameters from Service Catalog
- `variables.tf` - Variable definitions for the Service Catalog parameters
- `outputs.tf` - Output definitions that will be shown to users after provisioning

## Prerequisites

1. Install the AWS Service Catalog Terraform Reference Engine in your AWS account
2. Add this product to Service Catalog by packaging and uploading it

## Installation

1. Package this product:
   ```
   cd /path/to/EKS
   zip -r eks-cluster-product.zip .
   ```

2. Upload the package to an S3 bucket:
   ```
   aws s3 cp eks-cluster-product.zip s3://my-service-catalog-products/
   ```

3. Create a Service Catalog product using the AWS Management Console or CLI, pointing to the S3 location of the package

4. Add the product to a portfolio and share it with end users

## Usage

End users can provision an EKS cluster through Service Catalog by:

1. Accessing the Service Catalog console
2. Finding the EKS Cluster product in the appropriate portfolio
3. Launching the product and configuring parameters
4. Reviewing and confirming the provisioning
5. Accessing the outputs after provisioning completes

## Security

The GitLab pipeline trigger token is embedded directly in the product with sensitivity marking to ensure it's not visible in logs or the console.

## Customization

If you need to customize the product for your organization:

1. Edit the `manifest.yaml` to modify parameters, default values, or descriptions
2. Update any Terraform modules in the main repository
3. Repackage and upload the updated product