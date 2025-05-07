#!/bin/bash
set -o xtrace

# Bootstrap script for EKS nodes
# This allows custom AMIs to properly join the EKS cluster

CLUSTER_NAME="${cluster_name}"
API_SERVER_URL="${cluster_endpoint}"
B64_CLUSTER_CA="${cluster_ca_cert}"
DNS_CLUSTER_IP="${dns_cluster_ip}"

%{if kubelet_extra_args != ""}
KUBELET_EXTRA_ARGS="${kubelet_extra_args}"  
%{endif}

%{if bootstrap_extra_args != ""}
BOOTSTRAP_EXTRA_ARGS="${bootstrap_extra_args}"
%{endif}

/etc/eks/bootstrap.sh $CLUSTER_NAME \
    --b64-cluster-ca $B64_CLUSTER_CA \
    --apiserver-endpoint $API_SERVER_URL \
    --dns-cluster-ip ${dns_cluster_ip} \
    %{if bootstrap_extra_args != ""}$BOOTSTRAP_EXTRA_ARGS%{endif} \
    %{if kubelet_extra_args != ""}--kubelet-extra-args "$KUBELET_EXTRA_ARGS"%{endif}