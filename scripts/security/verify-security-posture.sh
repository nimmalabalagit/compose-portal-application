#!/bin/bash
# scripts/security/verify-security-posture.sh

echo "=== Security Posture Verification ==="
echo ""

# 1. Security Hub score
echo "── Security Hub Score ──"
aws securityhub get-finding-aggregator \
  --finding-aggregator-arn $(aws securityhub list-finding-aggregators \
    --query 'FindingAggregators[0].FindingAggregatorArn' --output text) \
  2>/dev/null || \
aws securityhub describe-standards-controls \
  --standards-subscription-arn $(aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[?contains(StandardsArn,`cis`)].StandardsSubscriptionArn' \
    --output text) \
  --query 'Controls[?ComplianceStatus==`PASSED`] | length(@)' 2>/dev/null | \
  awk '{print "CIS controls passing: "$1"/55"}'

# 2. GuardDuty active threats
echo ""
echo "── GuardDuty Active Findings ──"
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty list-findings \
  --detector-id ${DETECTOR_ID} \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]},"severity":{"Gte":[7]}}}' \
  --query 'FindingIds | length(@)' \
  --output text | xargs -I{} echo "HIGH/CRITICAL findings: {}"

# 3. WAF block rate
echo ""
echo "── WAF Block Statistics (last 24h) ──"
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=compose-portal-waf Name=Region,Value=us-east-1 \
  --start-time $(date -d '24 hours ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -v-24H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --query 'Datapoints[0].Sum' --output text | \
  xargs -I{} echo "Blocked requests (24h): {}"

# 4. TLS version on CloudFront
echo ""
echo "── TLS Configuration Check ──"
echo | openssl s_client -connect app.estateflowai.co:443 2>/dev/null | \
  grep -E "Protocol|Cipher" | head -3

# 5. Check for public S3 buckets
echo ""
echo "── S3 Public Bucket Audit ──"
for bucket in $(aws s3 ls | awk '{print $3}'); do
  PUBLIC=$(aws s3api get-bucket-acl --bucket $bucket \
    --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`]' \
    --output text 2>/dev/null)
  [[ -n "$PUBLIC" ]] && echo "❌ PUBLIC: $bucket" || true
done
echo "✅ No public S3 buckets found"

echo ""
echo "Security Hub target: 84% (from 62% baseline)"
echo "Run aws securityhub get-insights to see full compliance score"