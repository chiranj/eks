# Using the PSB1 Helm Base Chart with GitLab CI

This guide explains how to use the PSB1 Helm Base Chart with GitLab CI to verify and deploy applications to an EKS cluster.

## Prerequisites

- Access to the GitLab repository
- AWS CLI installed
- Helm CLI installed
- kubectl installed

## Using the Existing GitLab CI Configuration

Your project should use the existing `.gitlab-ci.yml` from the master branch. There's no need to create a new one. Instead, focus on updating your `values.yaml` file to configure the base Helm chart for your specific application needs.

The existing GitLab CI pipeline will handle:
- Validating your Helm chart
- Running template tests
- Deploying to the appropriate environment

## Accessing EKS Cluster from CLI (Manual Verification)

To manually verify deployments or troubleshoot issues, follow these steps to access the EKS cluster from your local environment:

### 1. Connect to AWS Bastion Host

```bash
ssh username@bastion-host.example.com
```

### 2. Authenticate to AWS Account

```bash
# Configure AWS CLI with your credentials
aws configure

# Or use SSO login if configured
aws sso login --profile your-profile
```

### 3. Get EKS Cluster Kubeconfig

```bash
# Update kubeconfig with EKS cluster info
aws eks update-kubeconfig --name your-cluster-name --region your-aws-region
```

### 4. Verify Access to the Cluster

```bash
kubectl get nodes
kubectl get pods -n your-namespace
```

## Testing Your Configuration with the Base Chart

To test your application configuration with the base Helm chart:

1. Add the base chart as a dependency in your `Chart.yaml`:

```yaml
dependencies:
  - name: psb1-helm-base-chart
    version: 0.1.0
    repository: "file://../psb1-helm-base-chart"  # Adjust path as needed
```

2. Create or update your application's `values.yaml` file with your specific configuration.

3. Validate locally before committing:

```bash
# Update dependencies
helm dependency update ./

# Test template rendering with your values
helm template ./ --values values.yaml

# Validate your chart
helm lint ./
```

The GitLab CI pipeline will automatically use your updated values when running the CI/CD process.

## Key Configuration Parameters

When using the base chart, focus on these essential configuration parameters in your `values.yaml`:

```yaml
# Application settings
name: your-app-name
replicaCount: 2

# Container settings
image:
  repository: your-repo/your-image
  tag: latest
  pullPolicy: Always

# Resource requirements
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Service configuration
service:
  type: ClusterIP
  port: 80

# Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

For more advanced configuration options, refer to the `default-values.yaml` file in the base chart repository.
