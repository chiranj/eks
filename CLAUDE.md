# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test/Lint Commands
- Init: `terraform init`
- Plan: `terraform plan`
- Apply: `terraform apply`
- Lint: `terraform fmt -check -recursive`
- Validate: `terraform validate`
- Test: `cd examples/complete && terraform init && terraform validate`

## Code Style Guidelines
- Terraform indentation: 2 spaces
- Use terraform-aws-modules where possible
- Follow Terraform best practices for module organization
- Document all variables with descriptions and data types
- Use conditional expressions for optional components
- Tag all resources consistently for cost tracking
- Follow proper naming convention: lowercase with hyphens (e.g., eks-cluster)
- Group related resources in the same module
- Keep modules focused and composable
- Security: Implement least privilege IAM permissions and use OIDC for authentication

## New Project change Instructions



Instead of making API calls from Terraform to trigger external pipelines to install helm charts,  expose your Terraform outputs as environment variables that can be used in subsequent pipeline stages or jobs: We are going to use Parent-Child Pipelines . Parent pipeline to execute terraform code and child ppipeline to install helm charts.
Best Practice: Hybrid Approach
I recommend a hybrid approach using both GitLab's dotenv artifacts and JSON files:

Basic variables via dotenv for simple environment variables
Structured data via JSON for complex resources like ARNs

Step 1: Update Terraform to Export Variables

```hcl
# In your Terraform code
locals {
  addon_resources = {
    external_dns_role_arn    = aws_iam_role.external_dns.arn
    cert_manager_role_arn    = aws_iam_role.cert_manager.arn
    opencost_role_arn        = aws_iam_role.opencost.arn
    cluster_name             = aws_eks_cluster.this.name
    aws_region               = var.region
    aws_account_id           = data.aws_caller_identity.current.account_id
  }
}

# Export as JSON file (for complex data)
resource "local_file" "addon_resources_json" {
  content  = jsonencode(local.addon_resources)
  filename = "${path.module}/terraform-outputs.json"
}

# Export as dotenv file (for environment variables)
resource "local_file" "addon_resources_env" {
  content  = join("\n", [
    "CLUSTER_NAME=${aws_eks_cluster.this.name}",
    "EXTERNAL_DNS_ROLE_ARN=${aws_iam_role.external_dns.arn}",
    "CERT_MANAGER_ROLE_ARN=${aws_iam_role.cert_manager.arn}",
    "OPENCOST_ROLE_ARN=${aws_iam_role.opencost.arn}",
    "AWS_REGION=${var.region}",
    "AWS_ACCOUNT_ID=${data.aws_caller_identity.current.account_id}"
  ])
  filename = "${path.module}/terraform-outputs.env"
}
```
Step 2: Configure GitLab CI to Use These Files. Child pipeline section in main gitlab-ci.yml

```hcl
helm-charts-deployment:
  stage: helm-charts
  needs:
    - terraform-apply
  # Include the helm charts pipeline from Project B
  include:
    - project: 'your-group/helm-charts-project'
      file: '.gitlab-ci.helm-charts.yml'
      ref: main
  # All variables from terraform-outputs.env are automatically available
  # to the included jobs from Project B
```

Step 3. 
Create .gitlab-ci.helm-charts.yml yaml file with following changes but for all add-on in the modules section

# This file lives in Project B but runs in Project A's context
stages:
  - prerequisites
  - dns
  - certs
  - monitoring

# These variables come from Project A's terraform-outputs.env
variables:
  KUBECONFIG: ./kubeconfig

setup-kubeconfig:
  stage: prerequisites
  script:
    - aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION --kubeconfig ./kubeconfig
  artifacts:
    paths:
      - ./kubeconfig

external-dns-install:
  stage: dns
  needs:
    - setup-kubeconfig
  script:
    - echo "Installing external-dns with role ARN: $EXTERNAL_DNS_ROLE_ARN"
    - helm upgrade --install external-dns external-dns/external-dns \
        --namespace external-dns \
        --create-namespace \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTERNAL_DNS_ROLE_ARN

cert-manager-install:
  stage: certs
  needs:
    - setup-kubeconfig
  script:
    - echo "Installing cert-manager with role ARN: $CERT_MANAGER_ROLE_ARN"
    - helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$CERT_MANAGER_ROLE_ARN

opencost-install:
  stage: monitoring
  needs:
    - setup-kubeconfig
  script:
    - echo "Installing opencost with role ARN: $OPENCOST_ROLE_ARN"
    - helm upgrade --install opencost opencost/opencost \
        --namespace opencost \
        --create-namespace \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$OPENCOST_ROLE_ARN