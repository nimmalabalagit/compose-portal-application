# k8s/base/finops/finops-dashboard.md
# FinOps Engineering Dashboard — EstateFlow AI

## Current Spend (ap-south-1)

| Resource | Daily Cost | Monthly Est | Optimization |
|----------|-----------|-------------|-------------|
| EKS nodes (3x t3.medium) | $3.34 | $100 | Use Spot 70% |
| Aurora PostgreSQL | $1.97 | $59 | Serverless v2 |
| DocumentDB | $1.82 | $55 | Scale down off-hours |
| NAT Gateway | $1.08 | $32 | VPC Endpoints |
| EKS Control Plane | $2.40 | $72 | Fixed cost |
| ALBs (3x) | $0.58 | $17 | Consolidate |
| Security Hub + GuardDuty | $0.50 | $15 | Required |
| Total | $11.69 | $350 | Target $250 |

## Unit Economics

| Metric | Value | Calculation |
|--------|-------|-------------|
| RPS sustained | 26.4 | k6 load test result |
| Requests per day | 2,280,960 | 26.4 x 86400 |
| Total daily cost | $11.69 | AWS Cost Explorer |
| Cost per request | $0.0000051 | $11.69 / 2,280,960 |
| Cost per 1000 req | $0.0051 | - |
| Cost per deploy | $0.15 | CI/CD pipeline cost |

## Savings Plan Coverage

| Coverage Type | Current | Target | Gap |
|--------------|---------|--------|-----|
| Compute SP | 0% | 62% | Need commitment |
| EC2 Instance SP | 0% | 20% | Need RI for Aurora |
| Total coverage | 0% | 75% | $45/month savings |

## Karpenter Spot Optimization

| Node Type | Count | Type | Cost/hr | Savings vs OD |
|-----------|-------|------|---------|---------------|
| t3.medium | 3 | On-Demand | $0.0464 | 0% |
| t3.medium | 3 | Spot | $0.0139 | 70% |
| Potential saving | - | - | - | $2.34/day |

Enable Spot: Add to Karpenter NodePool:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: [spot, on-demand]

## Rightsizing Recommendations (Compute Optimizer)

| Service | Current | Recommended | Monthly Saving |
|---------|---------|-------------|----------------|
| gateway-service | 500m CPU / 512Mi | 250m / 256Mi | $0.30 |
| user-service | 500m CPU / 512Mi | 200m / 256Mi | $0.25 |
| product-service | 500m CPU / 512Mi | 200m / 256Mi | $0.25 |
| order-service | 500m CPU / 512Mi | 300m / 384Mi | $0.15 |
| Total | - | - | $0.95/month |

## Cost Anomaly Thresholds

| Service | Normal Daily | Alert Threshold | Action |
|---------|-------------|-----------------|--------|
| EC2/EKS | $3.34 | +50% = $5.01 | Check Karpenter scaling |
| RDS | $1.97 | +30% = $2.56 | Check slow queries |
| NAT Gateway | $1.08 | +100% = $2.16 | Check for data leak |
| Total | $11.69 | +20% = $14.03 | Immediate investigation |

## Monthly FinOps Review Checklist

1. Review Kubecost namespace breakdown
2. Check Karpenter Spot adoption percentage
3. Review Compute Optimizer rightsizing
4. Savings Plans coverage gap analysis
5. Tag compliance audit (untagged resources)
6. Idle resource report (pods with < 5% CPU usage)
7. Data transfer cost breakdown (NAT vs VPC Endpoint)
8. Publish showback report to team leads
