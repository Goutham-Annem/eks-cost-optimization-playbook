#!/usr/bin/env bash
# find-idle-namespaces.sh — finds namespaces with no Running pods or zero CPU requests
set -euo pipefail

echo "=== Namespaces with no running pods ==="
kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read ns; do
  running=$(kubectl get pods -n "$ns" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$running" -eq 0 ]; then
    echo "  IDLE: $ns (0 running pods)"
  fi
done

echo ""
echo "=== Top namespaces by CPU request ==="
kubectl get pods -A --field-selector=status.phase=Running \
  -o custom-columns="NS:.metadata.namespace,CPU:.spec.containers[*].resources.requests.cpu" \
  | grep -v "<none>" \
  | awk 'NR>1 {
      ns=$1; cpu=$2
      # strip units
      gsub("m","",cpu)
      sum[ns]+=cpu
    }
    END {
      for (ns in sum) printf "%8d m  %s\n", sum[ns], ns
    }' \
  | sort -rn \
  | head -20

echo ""
echo "=== Deployments with no resource requests set ==="
kubectl get deployments -A -o json \
  | jq -r '.items[] | select(
      .spec.template.spec.containers[].resources.requests == null
    ) | "\(.metadata.namespace)/\(.metadata.name)"'
