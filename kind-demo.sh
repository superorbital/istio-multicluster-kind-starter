#!/bin/bash

set -euv
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

METALLB_VERSION=v0.14.5

mkdir -p istio/generated
mkdir -p clusters/generated
both_contexts() {
  for i in {1..2}
  do
    file=$(echo $1 | sed "s/{i}/$i/")
    kubectl apply -f $file --context "kind-so${i}"
  done
}
both_contexts_command() {
  arg="--context"
  if [ $# -gt 1 ]; then
    arg="--$2"
  fi
  for i in {1..2}
  do
    cmd=$(echo $1 | sed "s/{i}/$i/")
    eval "$cmd $arg kind-so${i}"
  done
}
in_context_func() {
  for i in {1..2}
  do
    export i
    kubectl config set-context kind-so$i
    $1
  done
}

# kind create cluster --config "${SCRIPT_DIR}/clusters/config-1.yaml" --name so1
# kind create cluster --config "${SCRIPT_DIR}/clusters/config-2.yaml" --name so2

both_contexts https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml

both_contexts_command "kubectl rollout status deploy -n metallb-system controller"

export first_two=$(docker network inspect -f '{{$map := index .IPAM.Config 0}}{{index $map "Subnet"}}' kind | awk -F. '{for(i=1;i<=2;i++){print $i}}' | tr '\n' '.')

sub_metallb() {
  envsubst < ${SCRIPT_DIR}/clusters/metallb.yaml > clusters/generated/metallb${i}.yaml
}
in_context_func sub_metallb

both_contexts clusters/generated/metallb{i}.yaml

(
  cd vault
  docker-compose up -d
  sleep 5
  export VAULT_ADDR=$(docker inspect vault | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')
  envsubst < ../clusters/coredns.yaml.tmpl > ../clusters/generated/coredns.yaml
)

both_contexts clusters/generated/coredns.yaml

both_contexts https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml

both_contexts_command "kubectl rollout status deploy -n cert-manager cert-manager-webhook"
both_contexts_command "kubectl rollout status deploy -n cert-manager cert-manager-cainjector"
both_contexts_command "kubectl rollout status deploy -n cert-manager cert-manager"

both_contexts_command "kubectl create ns istio-system"
both_contexts clusters/vault-token-secret.yaml

sub_vault() {
  envsubst < ${SCRIPT_DIR}/clusters/vault-issuer.yaml > clusters/generated/vault-issuer${i}.yaml
}
in_context_func sub_vault

both_contexts clusters/generated/vault-issuer{i}.yaml

both_contexts_command "helm upgrade --install -n istio-system cert-manager-istio-csr -f clusters/csr-values.yaml --set app.server.clusterID=istio-so{i} --version 0.9.0 jetstack/cert-manager-istio-csr" "kube-context"

both_contexts_command "kubectl rollout status deploy -n istio-system cert-manager-istio-csr"

deploy_istio() {
  echo "Starting istio deployment in cluster${i}"

  kubectl --context "kind-so${i}" get namespace istio-system && \
    kubectl --context "kind-so${i}" label --overwrite namespace istio-system topology.istio.io/network="network${i}"

  sed -e "s/{i}/${i}/" istio/cluster.yaml > "istio/generated/cluster${i}.yaml"
  istioctl install --context "kind-so${i}" --force -y -f "istio/generated/cluster${i}.yaml"

  echo "Generate eastwest gateway in cluster${i}"
  ${SCRIPT_DIR}/istio/gen-eastwest-gateway.sh \
      --mesh "mesh1" --cluster "istio-so${i}" --network "network${i}" | \
      istioctl --context "kind-so${i}" install -y -f -
}

in_context_func deploy_istio

both_contexts "istio/expose-services.yaml"
both_contexts "istio/telemetry.yaml"

connect_cluster() {
  docker_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "so${i}-control-plane")
  istioctl create-remote-secret \
  --context="kind-so${i}" \
  --server="https://${docker_ip}:6443" \
  --name="istio-so${i}" > istio/generated/so${i}-control-plane.yaml
}

in_context_func connect_cluster

apply_connect() {
  j=$((i %2 + 1))
  kubectl --context "kind-so${i}" apply -f istio/generated/so${j}-control-plane.yaml
}

in_context_func apply_connect

both_contexts "clusters/app.yaml"