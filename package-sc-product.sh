#!/bin/bash
set -e

# Ensure we're in the repository root
cd "$(dirname "$0")"

# Run validation
echo "Running validation checks..."
./validate.sh

# Create output directory
OUTPUT_DIR="build"
mkdir -p "$OUTPUT_DIR"

# Package the Service Catalog Terraform product
echo "Packaging Service Catalog Terraform product..."
zip -r "$OUTPUT_DIR/eks-cluster-product.zip" . -x "*.git*" "$OUTPUT_DIR/*"

echo "Product package created at: $OUTPUT_DIR/eks-cluster-product.zip"
echo ""
echo "To upload to S3 and create a Service Catalog product:"
echo "1. Upload the package to S3:"
echo "   aws s3 cp $OUTPUT_DIR/eks-cluster-product.zip s3://my-service-catalog-products/"
echo ""
echo "2. Create a Service Catalog product pointing to the S3 location"
echo "   (Use the AWS Management Console or CLI for this step)"
echo ""
echo "3. Add the product to a portfolio and share with end users"