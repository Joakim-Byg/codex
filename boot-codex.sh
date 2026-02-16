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
         --timeout "${time_out}s" > /dev/null) &
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
await_ready "Waiting for flux services ..." "30" "app.kubernetes.io/instance in (flux-operator)" "supporting-facility"

printf "\n\nSetting up flux instance...\n"
echo "######################################"
kubectl apply -f cluster-resources/supporting-facility/bootstrap/flux-instance.yaml
await_ready "Setup load timeout... " "10"
await_ready "Waiting for flux instance ..." "30" "app.kubernetes.io/part-of in (flux)" "supporting-facility"
printf "\n\nDone setting up flux!\n"

#kubectl apply -f cluster-resources/supporting-facility/source.yaml
kubectl apply -k cluster-resources/codex/config/.
