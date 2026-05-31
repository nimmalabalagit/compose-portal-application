# EstateFlow AI - Disaster Recovery Runbook

## DR Strategy: Pilot Light
- RTO: 30 minutes
- RPO: 5 minutes
- Primary Region: ap-south-1 Mumbai
- DR Region: us-east-1 Virginia

## Architecture

Primary ap-south-1:
  EKS compose-portal-eks
  Aurora Primary cluster
  ECR repositories
  Route53 PRIMARY record pointing to ap-south-1 ALB

DR us-east-1 (Pilot Light - scaled to 0 until failover):
  EKS compose-portal-dr-eks desiredSize=0
  Aurora Global DB Secondary read-only replica RPO less than 1s
  ECR cross-region replication automatic
  Route53 SECONDARY record auto-activates when primary fails

## Automated Failover

Route53 health check monitors api.estateflowai.co/actuator/health every 30s.
After 3 consecutive failures DNS automatically switches to us-east-1 ALB.
No manual intervention required for DNS failover.

## Manual Failover Steps

Step 1 - Confirm outage 2 min:
  curl https://api.estateflowai.co/actuator/health
  aws eks describe-cluster --name compose-portal-dev-eks --region ap-south-1

Step 2 - Scale up DR EKS 5 min:
  aws eks update-nodegroup-config
    --cluster-name compose-portal-dr-eks
    --nodegroup-name compose-portal-dr-system
    --scaling-config minSize=2,maxSize=5,desiredSize=3
    --region us-east-1

Step 3 - Promote Aurora secondary 5 min:
  aws rds failover-global-cluster
    --global-cluster-identifier estateflowai-global
    --target-db-cluster-identifier estateflowai-dr
    --region us-east-1

Step 4 - Update SSM Parameter Store 3 min:
  aws ssm put-parameter
    --name /compose-portal/order-service/db/url
    --value jdbc:postgresql://DR_ENDPOINT:5432/orders_db
    --overwrite --region us-east-1

Step 5 - ArgoCD sync DR cluster 5 min:
  aws eks update-kubeconfig --name compose-portal-dr-eks --region us-east-1
  argocd app sync compose-portal-dr

Step 6 - Verify 5 min:
  curl https://api.estateflowai.co/actuator/health
  curl https://api.estateflowai.co/api/users

Step 7 - Communicate parallel to above:
  Update Statuspage - Failover in progress estimated 30min
  Notify VP Engineering and on-call team
  Open war room inc-YYYYMMDD-dr in Slack

## RTO Calculation

Health check detection 3x30s = 90 seconds
DNS TTL expiry 300s = 5 minutes
EKS node scale-up = 5 minutes
Aurora promotion = 5 minutes
App pods ready = 10 minutes
Total RTO = 30 minutes

## RPO Calculation

Aurora Global DB replication lag = less than 1 second
ECR image replication lag = less than 5 minutes
Total RPO = less than 5 minutes

## Failback to Primary

1. Ensure primary region is stable
2. Failover back:
   aws rds failover-global-cluster
     --global-cluster-identifier estateflowai-global
     --target-db-cluster-identifier estateflowai-primary
     --region ap-south-1
3. Scale down DR EKS:
   aws eks update-nodegroup-config
     --cluster-name compose-portal-dr-eks
     --scaling-config minSize=0,maxSize=5,desiredSize=0
     --region us-east-1
4. Route53 health check passes - DNS auto-returns to primary

## Quarterly DR Test

Automated Lambda runs every quarter via EventBridge cron 0 2 1 every 3 months.
Manual test:
  aws lambda invoke
    --function-name estateflowai-dr-test
    --region ap-south-1
    /tmp/dr-test-result.json

## Interview Talking Points

Q: What is your RTO and RPO?
A: RTO 30min RPO 5min. Pilot Light to us-east-1.
   Aurora Global Database replicates with less than 1s lag.
   Route53 health check auto-fails DNS after 3 failed checks.
   DR EKS stays at 0 nodes saving cost until failover needed.

Q: Why Pilot Light over Warm Standby?
A: Cost. Warm Standby runs full replicas 24/7 adding $40/day.
   Pilot Light keeps DR EKS at 0 nodes scales in 5min on failover.
   For EstateFlow AI SLA of 99.95% 30min RTO is acceptable.
   99.99% SLA would require Warm Standby.

Q: How do you test DR?
A: Quarterly automated Lambda via EventBridge.
   Tests Aurora DR reachable and ECR images exist in us-east-1.
   Results to SNS and Slack on-call channel.
   SOC2 A1.2 requires annual test we exceed with quarterly.
