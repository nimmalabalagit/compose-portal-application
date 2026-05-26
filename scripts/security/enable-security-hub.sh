#!/bin/bash
# scripts/security/enable-security-hub.sh
# WHY Security Hub:
# Security Hub aggregates findings from 5 sources into one score:
# 1. AWS Config Rules (200+ compliance checks)
# 2. GuardDuty (threat detection — unusual API calls, bitcoin mining, C2 traffic)
# 3. Inspector v2 (ECR container vulnerability scanning)
# 4. Macie (S3 sensitive data discovery — PII, credentials, PHI)
# 5. IAM Access Analyzer (external access to your resources)
# The CIS AWS Foundations Benchmark score (your 62% baseline) checks 50+ controls:
# MFA on root, no public S3 buckets, CloudTrail enabled in all regions, etc.
# Target: 84% (passing all HIGH severity controls, some MEDIUM gaps acceptable for now)

set -euo pipefail

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="371056712467"

echo "=== Step 1: Enable CloudTrail (multi-region) ==="
# WHY multi-region CloudTrail:
# CIS Benchmark control 2.1 requires CloudTrail enabled in all regions.
# Without it: an attacker can create resources in us-west-2 while you're watching ap-south-1.
# Multi-region trail sends all events to one S3 bucket — centralized audit log.

TRAIL_BUCKET="compose-portal-cloudtrail-${AWS_ACCOUNT_ID}"

# Create S3 bucket for CloudTrail logs
aws s3 mb s3://${TRAIL_BUCKET} --region ${AWS_REGION}

# Block public access (CIS 2.3)
aws s3api put-public-access-block \
  --bucket ${TRAIL_BUCKET} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Bucket policy: allow CloudTrail to write, deny non-SSL access
aws s3api put-bucket-policy \
  --bucket ${TRAIL_BUCKET} \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"AWSCloudTrailAclCheck\",
        \"Effect\": \"Allow\",
        \"Principal\": {\"Service\": \"cloudtrail.amazonaws.com\"},
        \"Action\": \"s3:GetBucketAcl\",
        \"Resource\": \"arn:aws:s3:::${TRAIL_BUCKET}\"
      },
      {
        \"Sid\": \"AWSCloudTrailWrite\",
        \"Effect\": \"Allow\",
        \"Principal\": {\"Service\": \"cloudtrail.amazonaws.com\"},
        \"Action\": \"s3:PutObject\",
        \"Resource\": \"arn:aws:s3:::${TRAIL_BUCKET}/AWSLogs/${AWS_ACCOUNT_ID}/*\",
        \"Condition\": {\"StringEquals\": {\"s3:x-amz-acl\": \"bucket-owner-full-control\"}}
      },
      {
        \"Sid\": \"DenyNonSSL\",
        \"Effect\": \"Deny\",
        \"Principal\": \"*\",
        \"Action\": \"s3:*\",
        \"Resource\": [\"arn:aws:s3:::${TRAIL_BUCKET}\",\"arn:aws:s3:::${TRAIL_BUCKET}/*\"],
        \"Condition\": {\"Bool\": {\"aws:SecureTransport\": \"false\"}}
      }
    ]
  }"

# Enable CloudTrail
aws cloudtrail create-trail \
  --name compose-portal-trail \
  --s3-bucket-name ${TRAIL_BUCKET} \
  --is-multi-region-trail \
  --include-global-service-events \
  --enable-log-file-validation \
  2>/dev/null || echo "Trail already exists"

aws cloudtrail start-logging --name compose-portal-trail
echo "✅ CloudTrail enabled (multi-region, log validation enabled)"

echo ""
echo "=== Step 2: Enable GuardDuty ==="
# WHY GuardDuty:
# GuardDuty uses ML + threat intelligence to detect:
# - Unusual API calls from Tor exit nodes → your IAM key may be compromised
# - EC2 instances communicating with known C2 (command-and-control) servers → malware
# - Cryptocurrency mining patterns on your EKS nodes → cryptojacking
# - IAM credential exfiltration → someone is using stolen credentials
# None of these appear in CloudTrail as "bad" — they look like normal API calls.
# GuardDuty understands context and behavioral patterns.

aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  2>/dev/null || echo "GuardDuty already enabled"

DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
echo "GuardDuty Detector ID: ${DETECTOR_ID}"
echo "✅ GuardDuty enabled (findings published every 15 minutes)"

echo ""
echo "=== Step 3: Enable Security Hub ==="
aws securityhub enable-security-hub \
  --enable-default-standards \
  2>/dev/null || echo "Security Hub already enabled"

# Enable CIS AWS Foundations Benchmark v1.4
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    "[{\"StandardsArn\":\"arn:aws:securityhub:${AWS_REGION}::standards/cis-aws-foundations-benchmark/v/1.4.0\"}]"

# Enable AWS Foundational Security Best Practices
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    "[{\"StandardsArn\":\"arn:aws:securityhub:${AWS_REGION}::standards/aws-foundational-security-best-practices/v/1.0.0\"}]"

echo "✅ Security Hub enabled with CIS Benchmark + AWS FSBP"
echo ""
echo "Wait 24h for initial score calculation. Baseline target: fix top 5 findings first."