#!/bin/bash

spinner() {
   # Spinner frames
   sp=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
   max_seq=$(echo "10*$2" | bc -l)
   sequence=$(seq 0 "$max_seq")
   for i in $sequence; do
      # shellcheck disable=SC2154
      printf "\r\033[K${sp[$i%7]} \033[34m$1\033[0m  %-30s" "$(($2-$i/10))"
      sleep 0.10
   done
   printf "\r\033[K${sp[$i%7]} \033[34m$1\033[0m  %-30s" "Done"
   echo ""
}

kind create cluster --config kind-cluster-config.yaml

echo "#############################"
echo "Installing flux-operator..."
echo "#############################"

helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace supporting-facility \
  --create-namespace

spinner "Waiting for flux services ..." "30"
kubectl apply -f cluster-resources/supporting-facility/flux-instance.yaml

spinner "Waiting for flux instance ..." "35"
kubectl apply -f cluster-resources/supporting-facility/source.yaml
kubectl apply -k cluster-resources/codex/config/.
