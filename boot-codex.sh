#!/bin/bash

# Spinner frames
sp=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
await_ready() {
   ready_check=0
   time_out=$2
   if [ $# -gt 2 ]; then
      ready_check=1
      label_match="$3"
      namespace="$4"
      time_out=$((time_out))
      (kubectl wait pods \
         --selector="$label_match" \
         --for=condition=Ready \
         -l "$label_match" \
         -n "$namespace" \
         --timeout "${time_out}s" 2>&1 > /dev/null) &
      wait_pid=$!
   else
      (sleep "$time_out") &
      wait_pid=$!
   fi

   #Print spinner
   i=0
   while kill -0 $wait_pid 2>/dev/null; do
     printf "\r\033[K${sp[$i%7]} \033[34m$1\033[0m  %-30s" "$(($2-$i/10))"
     sleep 0.10
     i=$((i+1))
   done

   if [[ $ready_check -eq 0 ]]; then
      printf "\r\033[K  \033[34m$1\033[0m  %-30s" ""
   else
      printf "\r\033[K  \033[34m$1\033[0m  %-30s" "Ready"
   fi
   echo ""
}

kind create cluster --config kind-cluster-config.yaml

echo ""
echo "Installing flux-operator..."
echo "######################################"
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace supporting-facility \
  --create-namespace
await_ready "Post-helm timeout... " "10"
await_ready "Waiting for flux services ..." "60" "app.kubernetes.io/instance in (flux-operator)" "supporting-facility"

printf "\n\nSetting up flux instance...\n"
echo "######################################"
kubectl apply -f cluster-resources/supporting-facility/bootstrap/flux-instance.yaml
await_ready "Setup load timeout... " "10"
await_ready "Waiting for flux instance ..." "120" "app.kubernetes.io/part-of in (flux)" "supporting-facility"
printf "\n\nDone setting up flux!\n"

printf "\n\nSetting up ValKey...\n"
echo "######################################"
kubectl apply -f https://github.com/hyperspike/valkey-operator/releases/download/v0.0.61/install.yaml
await_ready "Setup load timeout... " "5"
await_ready "Waiting for ValKey controller ..." "60" "control-plane in (controller-manager)" "valkey-operator-system"

kubectl apply -f cluster-resources/supporting-facility/bootstrap/valkey-config.yaml
await_ready "Valkey cluster load timeout... " "5"
await_ready "Waiting for ValKey cluster ..." "60" "app.kubernetes.io/component in (valkey)" "supporting-facility"
printf "\n\nDone setting up ValKey!\n"

#kubectl apply -f cluster-resources/supporting-facility/source.yaml
#kubectl apply -k cluster-resources/codex/config/.
kubectl apply -k cluster-resources/supporting-facility/bootstrap/flux-enabled/.
