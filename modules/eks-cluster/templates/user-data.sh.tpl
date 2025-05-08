MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"

--//
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

# Log bootstrap process for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Basic system configuration
swapoff -a
set -o xtrace

# Enable IP forwarding for Kubernetes networking
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure kernel parameters for Kubernetes
cat <<EOF > /etc/sysctl.d/99-kubernetes.conf
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
vm.max_map_count = 262144
EOF
sysctl --system

# Set bootstrap parameters - these are CRUCIAL for proper node joining
CLUSTER_NAME=${cluster_name}
API_SERVER_URL=${cluster_endpoint}
B64_CLUSTER_CA=${cluster_ca_cert}
DNS_CLUSTER_IP=${dns_cluster_ip}
SERVICE_IPV4_CIDR=${service_ipv4_cidr}
MAX_PODS=${max_pods}

# If API server URL is empty, fetch it using AWS CLI (for resilience)
if [ -z "$API_SERVER_URL" ] || [[ "$API_SERVER_URL" == *"placeholder"* ]]; then
  echo "API Server URL not available from Terraform, fetching from AWS..."
  API_SERVER_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.endpoint" --output text)
  B64_CLUSTER_CA=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.certificateAuthority.data" --output text)
fi

echo "Using cluster: $CLUSTER_NAME"
echo "API Server: $API_SERVER_URL"

# Run EKS bootstrap script with complete configuration
/etc/eks/bootstrap.sh $CLUSTER_NAME \
    --b64-cluster-ca $B64_CLUSTER_CA \
    --apiserver-endpoint $API_SERVER_URL \
    --dns-cluster-ip $DNS_CLUSTER_IP \
    --service-ipv4-cidr $SERVICE_IPV4_CIDR \
    --use-max-pods false \
    --kubelet-extra-args "--max-pods=$MAX_PODS"

# Ensure kubelet is enabled and started
systemctl enable kubelet
systemctl restart kubelet

# Print status for logging
echo "Node bootstrap completed"
kubelet --version
echo "Waiting for node to join the cluster..."

--//--