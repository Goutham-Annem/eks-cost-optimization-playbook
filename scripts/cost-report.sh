#!/usr/bin/env bash
# cost-report.sh — pulls last 30 days of EKS-related costs from AWS Cost Explorer
set -euo pipefail

CLUSTER_NAME="${1:-my-cluster}"
END_DATE=$(date +%Y-%m-%d)
START_DATE=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)

echo "=== EKS Cost Report: $CLUSTER_NAME ==="
echo "Period: $START_DATE → $END_DATE"
echo ""

echo "--- EC2 (compute nodes) ---"
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --filter '{
    "And": [
      {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}},
      {"Tags": {"Key": "eks:cluster-name", "Values": ["'"$CLUSTER_NAME"'"]}}
    ]
  }' \
  --metrics BlendedCost \
  --query 'ResultsByTime[*].{Period:TimePeriod.Start, Cost:Total.BlendedCost.Amount, Unit:Total.BlendedCost.Unit}' \
  --output table

echo ""
echo "--- Data Transfer ---"
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["AWS Data Transfer"]}}' \
  --metrics BlendedCost \
  --query 'ResultsByTime[*].{Period:TimePeriod.Start, Cost:Total.BlendedCost.Amount}' \
  --output table

echo ""
echo "--- Spot vs On-Demand split (Karpenter node labels) ---"
kubectl get nodes \
  -l karpenter.sh/capacity-type \
  -o custom-columns="NAME:.metadata.name,TYPE:.metadata.labels.karpenter\.sh/capacity-type,INSTANCE:.metadata.labels.node\.kubernetes\.io/instance-type" \
  | sort -k2
