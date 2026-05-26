#!/bin/bash
# scripts/chaos/setup-fis.sh
# WHY AWS FIS instead of chaos-monkey or manual pod deletion:
# AWS FIS is managed, audited, and integrates with Stop Conditions.
# Stop Conditions: if your CloudWatch alarm fires (e.g. error rate > 5%),
# FIS automatically stops the experiment — safe for production use.
# Manual chaos: no guardrails, no audit trail, "oops I deleted prod pods".
# AWS FIS: every experiment is logged in CloudTrail. CISO-approved chaos.

set -euo pipefail

AWS_REGION="ap-south-1"
CLUSTER_NAME="compose-portal-eks"
NAMESPACE="compose-portal"

# Create IAM role for FIS experiments
aws iam create-role \
  --role-name FISExperimentRole \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"fis.amazonaws.com"},
      "Action":"sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "FIS role already exists"

# Attach EKS experiment permissions
aws iam put-role-policy \
  --role-name FISExperimentRole \
  --policy-name FISEKSPolicy \
  --policy-document '{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Effect":"Allow",
        "Action":["eks:*","ec2:*","cloudwatch:*","logs:*","ssm:SendCommand","ssm:GetCommandInvocation"],
        "Resource":"*"
      }
    ]
  }'

FIS_ROLE_ARN=$(aws iam get-role --role-name FISExperimentRole --query 'Role.Arn' --output text)

# Create Stop Condition alarm (stops FIS if error rate exceeds threshold)
# WHY Stop Condition is mandatory:
# Without it, FIS continues injecting faults even as your service collapses.
# Stop Condition = "abort experiment if things go too wrong"
aws cloudwatch put-metric-alarm \
  --alarm-name "compose-portal-fis-stop-condition" \
  --alarm-description "FIS Stop Condition: too many 5xx errors" \
  --metric-name "5xxErrorRate" \
  --namespace "ComposePortal/Applications" \
  --statistic Average \
  --period 60 \
  --threshold 5.0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

STOP_CONDITION_ARN=$(aws cloudwatch describe-alarms \
  --alarm-names "compose-portal-fis-stop-condition" \
  --query 'MetricAlarms[0].AlarmArn' --output text)