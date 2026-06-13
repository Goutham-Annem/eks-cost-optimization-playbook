# eks-cost-optimization-playbook

> A complete guide to cutting EKS costs by 40–70%: Karpenter + Spot, right-sizing, idle cleanup, and Savings Plans strategy.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Cost levers covered

| Lever | Typical saving | Effort |
|-------|---------------|--------|
| Spot instances via Karpenter | 60–90% node cost | Low |
| VPA right-sizing | 20–40% resource waste | Medium |
| Idle namespace cleanup | 10–30% | Low |
| Savings Plans (compute) | 30–50% on committed workloads | Low |
| S3 lifecycle policies | 40–80% on old objects | Low |
| NAT Gateway optimization | 20–50% data transfer | Medium |

## Architecture: Cost-optimized EKS

```
                    Workloads
                       │
                       ▼
         ┌─────────────────────────┐
         │   Karpenter NodePool    │
         │  ┌─────┐  ┌─────────┐  │
         │  │Spot │  │On-Demand│  │
         │  │80%  │  │  20%   │  │
         │  └─────┘  └─────────┘  │
         └─────────────────────────┘
                       │
         ┌─────────────▼───────────┐
         │      VPA + HPA          │
         │  Right-size pods        │
         │  Scale out on load      │
         └─────────────────────────┘
                       │
         ┌─────────────▼───────────┐
         │   Cost Visibility       │
         │   Kubecost / CUDOS      │
         └─────────────────────────┘
```

## Quick wins (do these first)

### 1. Enable Spot for non-critical workloads
```yaml
# karpenter/nodepool-spot.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot-general
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: [m5.large, m5.xlarge, m5a.large, m5a.xlarge, m6i.large, m6i.xlarge, m6a.large]
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
  limits:
    cpu: "500"
```

### 2. VPA in recommendation mode (no auto-apply yet)
```bash
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vertical-pod-autoscaler.yaml

# Get recommendations without changing anything
kubectl get vpa -A -o yaml | grep -A5 "recommendation"
```

### 3. Find idle namespaces
```bash
# scripts/find-idle-namespaces.sh
kubectl get pods -A --field-selector=status.phase=Running \
  -o custom-columns="NS:.metadata.namespace,CPU:.spec.containers[*].resources.requests.cpu" \
  | sort | uniq -c | sort -rn
```

### 4. NAT Gateway — move traffic to VPC endpoints
```bash
# Check what's going through NAT (costs $0.045/GB)
# High culprits: ECR pulls, S3 access, SSM, CloudWatch
# Fix: Add VPC endpoints for each
```

## Terraform

```bash
cd terraform/
terraform init
terraform apply -var="cluster_name=my-cluster"
# Creates: Karpenter NodePools, VPC endpoints, S3 lifecycle rules, cost allocation tags
```

## Cost dashboard

The included Grafana dashboard shows:
- Hourly spend by namespace
- Spot vs On-Demand ratio
- Top 10 most expensive pods
- CPU/Memory waste per deployment
- Projected monthly spend

## Files

```
eks-cost-optimization-playbook/
├── karpenter/
│   ├── nodepool-spot.yaml
│   ├── nodepool-ondemand-system.yaml
│   └── ec2nodeclass.yaml
├── vpa/
│   └── vpa-recommendations.yaml
├── terraform/
│   └── main.tf           # VPC endpoints, lifecycle rules, tagging
├── scripts/
│   ├── find-idle-namespaces.sh
│   ├── cost-report.sh    # Pulls from Cost Explorer API
│   └── right-size-report.sh
└── runbooks/
    ├── 01-spot-interruption-handling.md
    └── 02-monthly-cost-review.md
```

## License

MIT — by [Goutham Annem](https://linkedin.com/in/goutham-annem)
