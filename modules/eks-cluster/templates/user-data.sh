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

# Bootstrap script for EKS nodes
# This allows custom AMIs to properly join the EKS cluster

CLUSTER_NAME="${cluster_name}"
API_SERVER_URL="${cluster_endpoint}"
B64_CLUSTER_CA="${cluster_ca_cert}"
DNS_CLUSTER_IP="${dns_cluster_ip}" 
SERVICE_IPV4_CIDR="${service_ipv4_cidr}"

%{if kubelet_extra_args != ""}
KUBELET_EXTRA_ARGS="${kubelet_extra_args}"  
%{endif}

%{if bootstrap_extra_args != ""}
BOOTSTRAP_EXTRA_ARGS="${bootstrap_extra_args}"
%{endif}

# Run EKS bootstrap script with max-pods control
/etc/eks/bootstrap.sh $CLUSTER_NAME \
    --b64-cluster-ca $B64_CLUSTER_CA \
    --apiserver-endpoint $API_SERVER_URL \
    --dns-cluster-ip ${dns_cluster_ip} \
    --service-ipv4-cidr $SERVICE_IPV4_CIDR \
    --use-max-pods false \
    %{if bootstrap_extra_args != ""}$BOOTSTRAP_EXTRA_ARGS%{endif} \
    %{if kubelet_extra_args != ""}--kubelet-extra-args "$KUBELET_EXTRA_ARGS --max-pods=${max_pods}" %{else}--kubelet-extra-args "--max-pods=${max_pods}"%{endif}

# Ensure kubelet is enabled and started
systemctl enable kubelet
systemctl restart kubelet

# Print status for logging
echo "Node bootstrap completed"
kubelet --version
echo "Waiting for node to join the cluster..."

--//--