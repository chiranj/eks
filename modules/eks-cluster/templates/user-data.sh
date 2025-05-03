#!/bin/bash
set -o xtrace

# Bootstrap script for EKS nodes
# This allows custom AMIs to properly join the EKS cluster

CLUSTER_NAME="${cluster_name}"
API_SERVER_URL="${cluster_endpoint}"
B64_CLUSTER_CA="${certificate_authority_data}"
SERVICE_IPV4_CIDR="${service_ipv4_cidr}"

%{if extra_kubelet_args != ""}
KUBELET_EXTRA_ARGS="${extra_kubelet_args}"  
%{endif}

%{if bootstrap_extra_args != ""}
BOOTSTRAP_EXTRA_ARGS="${bootstrap_extra_args}"
%{endif}

/etc/eks/bootstrap.sh $CLUSTER_NAME \
    --b64-cluster-ca $B64_CLUSTER_CA \
    --apiserver-endpoint $API_SERVER_URL \
    --dns-cluster-ip ${dns_cluster_ip} \
    %{if service_ipv4_cidr != ""}--service-ipv4-cidr ${service_ipv4_cidr}%{endif} \
    %{if bootstrap_extra_args != ""}$BOOTSTRAP_EXTRA_ARGS%{endif} \
    %{if kubelet_extra_args != ""}--kubelet-extra-args "$KUBELET_EXTRA_ARGS"%{endif}