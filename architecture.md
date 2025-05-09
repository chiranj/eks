# AWS EKS Architecture

This document provides a high-level architecture overview of the EKS cluster deployment using Terraform modules.

## Core Architecture

```mermaid
graph TD
    subgraph AWS_Account
        subgraph EKS_Cluster["EKS Cluster"]
            CP[Control Plane] 
            NG[Node Groups]
            
            subgraph Addons["EKS Add-ons"]
                CSI_Drivers["Storage Drivers\n(EBS/EFS CSI)"]
                CoreAddons["Core Add-ons\n(CoreDNS, kube-proxy, VPC CNI)"]
                OptAddons["Optional Add-ons\n(cert-manager, external-dns, etc)"]
            end
        end
        
        IAM_Roles["IAM Roles"]
        OIDC["OIDC Provider"]
        SG["Security Groups"]
        LT["Launch Templates"]
    end
    
    CP --> OIDC
    OIDC --> IAM_Roles
    NG --> LT
    CP --> SG
    NG --> SG
    IAM_Roles --> Addons
```

## Deployment Flow

```mermaid
flowchart LR
    A[1. Create EKS Cluster] --> B[2. Create OIDC Provider]
    B --> C[3. Create Add-on IAM Roles]
    C --> D[4. Install EKS Add-ons]
```

## Component Overview

### 1. EKS Control Plane
- Managed Kubernetes control plane hosted by AWS
- Configured with public and/or private endpoint access
- Custom security groups for API server access
- Uses `cluster_iam_role_arn` to support pre-created IAM roles

### 2. EKS Node Groups
- Managed node groups with customizable instance types
- Custom launch templates for advanced configuration
- Automatic scaling configurations
- Uses `node_iam_role_arn` to support pre-created IAM roles

### 3. Launch Templates
- Custom user data for node bootstrapping
- Root volume configuration (gp3, encrypted storage)
- Enhanced metadata security (IMDSv2)
- Tags for cost allocation and resource management

### 4. Security Groups
- Cluster security group: Controls access to the Kubernetes API server
- Node security group: Controls traffic to/from worker nodes
- Added rules to allow VPC CIDR access to the cluster

### 5. IAM Integration
- Support for IAM Roles for Service Accounts (IRSA)
- EKS OIDC provider for secure pod authentication
- Scoped IAM permissions following least privilege principle
- Conditional IAM role creation based on feature flags

### 6. Add-ons Architecture

Each add-on follows the same pattern:
1. IAM role with trusted relationship to the EKS OIDC provider
2. Add-on-specific policy with minimal permissions required
3. Service account binding in Kubernetes
4. Native EKS add-on or Helm chart deployment

```mermaid
graph TD
    subgraph AWS
        OIDC[OIDC Provider]
        IAM[IAM Role]
        Policy[IAM Policy]
    end
    
    subgraph Kubernetes
        SA[Service Account]
        Addon[Add-on Pod]
    end
    
    OIDC -- Trust --> IAM
    Policy -- Permissions --> IAM
    IAM -- Assumed by --> SA
    SA -- Used by --> Addon
    Addon -- Accesses --> AWS_Services[AWS Services]
```

## Two-Phase Deployment

The architecture supports a two-phase deployment approach to resolve circular dependencies:

1. **Phase 1**: Deploy EKS cluster without add-ons
   - EKS control plane
   - Node groups
   - OIDC provider

2. **Phase 2**: Deploy add-ons using the OIDC provider from Phase 1
   - Create IRSA roles for add-ons
   - Install EKS managed add-ons
   - Deploy additional components

This approach solves the "chicken-and-egg" problem with the OIDC provider, which is needed for add-on roles but is only created after the EKS cluster exists.