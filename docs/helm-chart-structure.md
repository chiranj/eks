# Helm Chart Structure for EKS Add-ons

This document describes how to structure your custom Helm charts repository for the EKS module's parent-child pipeline integration.

## Repository Structure

Create a Git repository with the following structure:

```
eks-helm-charts/
├── aws-ebs-csi-driver/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   └── ...
│   └── repositories.txt
├── aws-load-balancer-controller/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   └── ...
│   └── repositories.txt
├── external-dns/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   └── ...
│   └── repositories.txt
└── ...other add-ons
```

## Chart Dependencies

For charts that depend on official repositories, create a `repositories.txt` file in each chart directory. This file tells the pipeline which Helm repositories to add before installing the chart.

### Example `repositories.txt` File Format

Each line should contain a repository name and URL, separated by a space:

```
eks https://aws.github.io/eks-charts
jetstack https://charts.jetstack.io
ingress-nginx https://kubernetes.github.io/ingress-nginx
prometheus-community https://prometheus-community.github.io/helm-charts
```

## Chart Configuration

### Chart.yaml

Standard Helm Chart.yaml file with dependencies if needed:

```yaml
apiVersion: v2
name: aws-load-balancer-controller
description: AWS Load Balancer Controller for Kubernetes
version: 1.0.0
appVersion: 2.5.2
dependencies:
  - name: aws-load-balancer-controller
    version: 1.5.3
    repository: https://aws.github.io/eks-charts
```

### values.yaml

Default values for the chart, which will be overridden with AWS-specific parameters:

```yaml
# Example values.yaml for AWS Load Balancer Controller
replicaCount: 1
region: us-east-1  # Will be overridden by pipeline

serviceAccount:
  create: true
  name: aws-load-balancer-controller
  # annotations will be added by the pipeline
  
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Pipeline Integration

The GitLab CI/CD pipeline will:

1. Clone your Helm charts repository
2. Add required Helm repositories from the `repositories.txt` file
3. Update dependencies if needed
4. Install charts with default values from `values.yaml`
5. Override critical parameters like IAM role ARNs with values from Terraform

## Environment Variables

The following variables can be set to customize the pipeline behavior:

- `HELM_CHARTS_REPO`: Git repository URL containing your Helm charts
- `HELM_CHARTS_REF`: Branch or tag to checkout (default: main)

## Add-on Specific Parameters

Each add-on receives parameters from Terraform outputs:

- `$ROLE_ARN`: IAM role ARN created by Terraform for the add-on
- `$CLUSTER_NAME`: EKS cluster name
- `$AWS_REGION`: AWS region where the cluster is deployed

## Creating a New Add-on

To add a new add-on:

1. Create a new directory in your Helm charts repository
2. Add Chart.yaml, values.yaml, and templates as needed
3. Create repositories.txt if your chart has dependencies
4. Add a new job in .gitlab-ci.helm-charts.yml using the template pattern
5. Create the corresponding IAM role module in the EKS Terraform code