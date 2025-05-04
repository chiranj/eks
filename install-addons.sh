#!/bin/bash
set -e

# Get cluster name from terraform output
echo "Retrieving cluster information from Terraform output..."
CLUSTER_NAME=$(terraform output -raw cluster_id)
REGION=$(terraform output -raw cluster_endpoint | sed 's/.*eks\.\(.*\)\.amazonaws\.com.*/\1/')

# Update kubeconfig
echo "Configuring kubectl to connect to cluster $CLUSTER_NAME in region $REGION..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Get IAM role ARNs
echo "Retrieving IAM role ARNs from Terraform output..."
LB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
KARPENTER_ROLE_ARN=$(terraform output -raw karpenter_role_arn 2>/dev/null || echo "")
EBS_CSI_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn 2>/dev/null || echo "")
EFS_CSI_ROLE_ARN=$(terraform output -raw efs_csi_driver_role_arn 2>/dev/null || echo "")
EXTERNAL_DNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn 2>/dev/null || echo "")
KEDA_ROLE_ARN=$(terraform output -raw keda_role_arn 2>/dev/null || echo "")
CERT_MANAGER_ROLE_ARN=$(terraform output -raw cert_manager_role_arn 2>/dev/null || echo "")
NGINX_INGRESS_ROLE_ARN=$(terraform output -raw nginx_ingress_role_arn 2>/dev/null || echo "")
ADOT_ROLE_ARN=$(terraform output -raw adot_role_arn 2>/dev/null || echo "")
FLUENT_BIT_ROLE_ARN=$(terraform output -raw fluent_bit_role_arn 2>/dev/null || echo "")
PROMETHEUS_ROLE_ARN=$(terraform output -raw prometheus_role_arn 2>/dev/null || echo "")
SECRETS_MANAGER_ROLE_ARN=$(terraform output -raw secrets_manager_role_arn 2>/dev/null || echo "")

# Create kube-system namespace if it doesn't exist (it should already exist)
kubectl get namespace kube-system >/dev/null 2>&1 || kubectl create namespace kube-system

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo add eks https://aws.github.io/eks-charts
helm repo add karpenter https://charts.karpenter.sh
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add keda https://kedacore.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Install add-ons based on which IAM roles exist
# AWS Load Balancer Controller
if [ -n "$LB_ROLE_ARN" ] && [ "$LB_ROLE_ARN" != "" ]; then
  echo "Installing AWS Load Balancer Controller..."
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=true \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LB_ROLE_ARN
fi

# EBS CSI Driver
if [ -n "$EBS_CSI_ROLE_ARN" ] && [ "$EBS_CSI_ROLE_ARN" != "" ]; then
  echo "Installing EBS CSI Driver..."
  helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
    --namespace kube-system \
    --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EBS_CSI_ROLE_ARN
fi

# EFS CSI Driver
if [ -n "$EFS_CSI_ROLE_ARN" ] && [ "$EFS_CSI_ROLE_ARN" != "" ]; then
  echo "Installing EFS CSI Driver..."
  helm upgrade --install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EFS_CSI_ROLE_ARN
fi

# Karpenter
if [ -n "$KARPENTER_ROLE_ARN" ] && [ "$KARPENTER_ROLE_ARN" != "" ]; then
  echo "Installing Karpenter..."
  helm upgrade --install karpenter karpenter/karpenter \
    --namespace kube-system \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$KARPENTER_ROLE_ARN \
    --set settings.aws.clusterName=$CLUSTER_NAME \
    --set settings.aws.clusterEndpoint=$(terraform output -raw cluster_endpoint) \
    --set settings.aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-$CLUSTER_NAME
fi

# External DNS
if [ -n "$EXTERNAL_DNS_ROLE_ARN" ] && [ "$EXTERNAL_DNS_ROLE_ARN" != "" ]; then
  echo "Installing External DNS..."
  # Extract domain from Terraform state or prompt user
  DOMAIN=$(terraform output -raw enabled_addons | jq -r '.external_dns.hosted_zone_name_servers[0]' 2>/dev/null || echo "")
  if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "null" ]; then
    read -p "Enter your domain for External DNS filter: " DOMAIN
  fi
  
  helm upgrade --install external-dns external-dns/external-dns \
    --namespace kube-system \
    --set provider=aws \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTERNAL_DNS_ROLE_ARN \
    --set domainFilters[0]=$DOMAIN
fi

# KEDA
if [ -n "$KEDA_ROLE_ARN" ] && [ "$KEDA_ROLE_ARN" != "" ]; then
  echo "Installing KEDA..."
  helm upgrade --install keda keda/keda \
    --namespace kube-system \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$KEDA_ROLE_ARN
fi

# Cert Manager
if [ -n "$CERT_MANAGER_ROLE_ARN" ] && [ "$CERT_MANAGER_ROLE_ARN" != "" ]; then
  echo "Installing Cert Manager..."
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace kube-system \
    --set installCRDs=true \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$CERT_MANAGER_ROLE_ARN
fi

# NGINX Ingress Controller
if [ -n "$NGINX_INGRESS_ROLE_ARN" ] && [ "$NGINX_INGRESS_ROLE_ARN" != "" ]; then
  echo "Installing NGINX Ingress Controller..."
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace kube-system \
    --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$NGINX_INGRESS_ROLE_ARN
fi

# Prometheus
if [ -n "$PROMETHEUS_ROLE_ARN" ] && [ "$PROMETHEUS_ROLE_ARN" != "" ]; then
  echo "Installing Prometheus..."
  helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --create-namespace \
    --set serviceAccounts.server.annotations."eks\.amazonaws\.com/role-arn"=$PROMETHEUS_ROLE_ARN
fi

# Fluent Bit
if [ -n "$FLUENT_BIT_ROLE_ARN" ] && [ "$FLUENT_BIT_ROLE_ARN" != "" ]; then
  echo "Installing Fluent Bit..."
  helm upgrade --install fluent-bit fluent/fluent-bit \
    --namespace logging \
    --create-namespace \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$FLUENT_BIT_ROLE_ARN
fi

# Display installed add-ons
echo ""
echo "===== ADD-ONS INSTALLATION SUMMARY ====="
kubectl get pods -A | grep -E "aws-load-balancer-controller|aws-ebs-csi-driver|aws-efs-csi-driver|karpenter|external-dns|keda|cert-manager|ingress-nginx|prometheus|fluent-bit"

echo ""
echo "Add-on installation complete!"
echo "Your EKS cluster is now ready to use."