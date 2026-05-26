#!/bin/bash
# scripts/security/deploy-cloudfront-waf.sh
# WHY CloudFront + WAF:
# 1. CloudFront: Terminates TLS at edge (157 PoPs), caches React static assets,
#    reduces ALB load by 40-60% for static content.
# 2. WAF: Blocks OWASP Top 10 attacks before they reach your ALB/EKS.
#    Without WAF: SQL injection, XSS, path traversal go straight to Spring Boot.
# 3. Cost: CloudFront data transfer is cheaper than ALB data transfer for global users.
# 4. DDoS: CloudFront + AWS Shield Standard absorbs volumetric attacks.
#    Your ALB has fixed capacity; CloudFront scales to terabits.

set -euo pipefail

AWS_ACCOUNT_ID="371056712467"
DOMAIN="estateflowai.co"
ALB_DNS="estateflowai-alb-1234567890.ap-south-1.elb.amazonaws.com"  # From Terraform output

# ── Step 1: Create WAF Web ACL ────────────────────────────────────────────────
echo "Creating WAF Web ACL..."
WAF_ACL=$(aws wafv2 create-web-acl \
  --name compose-portal-waf \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --default-action Allow={} \
  --rules '[
    {
      "Name": "AWSManagedRulesCommonRuleSet",
      "Priority": 1,
      "OverrideAction": {"None": {}},
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "CommonRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesSQLiRuleSet",
      "Priority": 2,
      "OverrideAction": {"None": {}},
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesSQLiRuleSet"
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "SQLiRuleSetMetric"
      }
    },
    {
      "Name": "RateLimitRule",
      "Priority": 3,
      "Action": {"Block": {}},
      "Statement": {
        "RateBasedStatement": {
          "Limit": 2000,
          "AggregateKeyType": "IP"
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitMetric"
      }
    },
    {
      "Name": "GeoBlockRule",
      "Priority": 4,
      "Action": {"Block": {}},
      "Statement": {
        "GeoMatchStatement": {
          "CountryCodes": ["RU", "KP", "IR", "CU", "SY"]
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "GeoBlockMetric"
      }
    }
  ]' \
  --visibility-config \
    "SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=ComposePortalWAF" \
  --query 'Summary.ARN' --output text)

echo "WAF Web ACL ARN: ${WAF_ACL}"

# ── Step 2: Create CloudFront Distribution ────────────────────────────────────
echo ""
echo "Creating CloudFront distribution..."

# Certificate ARN (must be in us-east-1 for CloudFront)
# Created via: aws acm request-certificate --domain-name estateflowai.co --region us-east-1
CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='estateflowai.co'].CertificateArn" \
  --output text)

aws cloudfront create-distribution \
  --distribution-config "{
    \"CallerReference\": \"compose-portal-$(date +%s)\",
    \"Comment\": \"EstateFlow AI — compose-portal\",
    \"WebACLId\": \"${WAF_ACL}\",
    \"Aliases\": {
      \"Quantity\": 2,
      \"Items\": [\"app.${DOMAIN}\", \"www.${DOMAIN}\"]
    },
    \"ViewerCertificate\": {
      \"ACMCertificateArn\": \"${CERT_ARN}\",
      \"SSLSupportMethod\": \"sni-only\",
      \"MinimumProtocolVersion\": \"TLSv1.2_2021\"
    },
    \"Origins\": {
      \"Quantity\": 2,
      \"Items\": [
        {
          \"Id\": \"ALB-origin\",
          \"DomainName\": \"${ALB_DNS}\",
          \"CustomOriginConfig\": {
            \"HTTPPort\": 80,
            \"HTTPSPort\": 443,
            \"OriginProtocolPolicy\": \"https-only\",
            \"OriginSSLProtocols\": {\"Quantity\": 1, \"Items\": [\"TLSv1.2\"]}
          },
          \"CustomHeaders\": {
            \"Quantity\": 1,
            \"Items\": [{
              \"HeaderName\": \"X-Origin-Verify\",
              \"HeaderValue\": \"${AWS_ACCOUNT_ID}-compose-portal-secret\"
            }]
          }
        },
        {
          \"Id\": \"S3-static\",
          \"DomainName\": \"compose-portal-static-${AWS_ACCOUNT_ID}.s3.ap-south-1.amazonaws.com\",
          \"S3OriginConfig\": {\"OriginAccessIdentity\": \"\"}
        }
      ]
    },
    \"DefaultCacheBehavior\": {
      \"TargetOriginId\": \"ALB-origin\",
      \"ViewerProtocolPolicy\": \"redirect-to-https\",
      \"CachePolicyId\": \"4135ea2d-6df8-44a3-9df3-4b5a84be39ad\",
      \"OriginRequestPolicyId\": \"216adef6-5c7f-47e4-b989-5492eafa07d3\",
      \"AllowedMethods\": {
        \"Quantity\": 7,
        \"Items\": [\"GET\",\"HEAD\",\"OPTIONS\",\"PUT\",\"POST\",\"PATCH\",\"DELETE\"],
        \"CachedMethods\": {\"Quantity\": 2, \"Items\": [\"GET\",\"HEAD\"]}
      },
      \"Compress\": true
    },
    \"CacheBehaviors\": {
      \"Quantity\": 1,
      \"Items\": [{
        \"PathPattern\": \"/assets/*\",
        \"TargetOriginId\": \"ALB-origin\",
        \"ViewerProtocolPolicy\": \"redirect-to-https\",
        \"CachePolicyId\": \"658327ea-f89d-4fab-a63d-7e88639e58f6\",
        \"Compress\": true,
        \"AllowedMethods\": {
          \"Quantity\": 2,
          \"Items\": [\"GET\",\"HEAD\"],
          \"CachedMethods\": {\"Quantity\": 2, \"Items\": [\"GET\",\"HEAD\"]}
        }
      }]
    },
    \"Enabled\": true,
    \"HttpVersion\": \"http2and3\",
    \"PriceClass\": \"PriceClass_200\"
  }" \
  --query 'Distribution.DomainName' --output text