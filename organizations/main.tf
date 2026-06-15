# EstateFlow AI — AWS Organizations Multi-Account Governance
# CODE ONLY — deploy when interview scheduled
# terraform apply -var-file=terraform.tfvars -auto-approve

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "compose-portal-terraform-state-371056712467"
    key            = "organizations/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "compose-portal-terraform-locks"
    encrypt        = true
  }
}

provider "aws" { region = "ap-south-1" }

# ── AWS Organization ─────────────────────────────────────────────────────────
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "securityhub.amazonaws.com",
    "guardduty.amazonaws.com",
  ]
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]
}

# ── Organisational Units ─────────────────────────────────────────────────────
resource "aws_organizations_organizational_unit" "dev" {
  name      = "Dev"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "staging" {
  name      = "Staging"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# ── SCP 1: Deny public S3 buckets ───────────────────────────────────────────
resource "aws_organizations_policy" "deny_public_s3" {
  name        = "DenyPublicS3"
  description = "Prevent any S3 bucket from being made public"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyPublicS3"
      Effect = "Deny"
      Action = ["s3:PutBucketAcl", "s3:PutObjectAcl", "s3:PutBucketPublicAccessBlock"]
      Resource = "*"
      Condition = {
        StringEquals = { "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"] }
      }
    }]
  })
}

# ── SCP 2: Require encryption at rest ───────────────────────────────────────
resource "aws_organizations_policy" "require_encryption" {
  name        = "RequireEncryptionAtRest"
  description = "Deny unencrypted RDS, EBS, and S3 without KMS"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedRDS"
        Effect = "Deny"
        Action = ["rds:CreateDBInstance", "rds:CreateDBCluster"]
        Resource = "*"
        Condition = { Bool = { "rds:StorageEncrypted" = "false" } }
      },
      {
        Sid    = "DenyUnencryptedEBS"
        Effect = "Deny"
        Action = ["ec2:CreateVolume"]
        Resource = "*"
        Condition = { Bool = { "ec2:Encrypted" = "false" } }
      }
    ]
  })
}

# ── SCP 3: Restrict to ap-south-1 only ──────────────────────────────────────
resource "aws_organizations_policy" "restrict_regions" {
  name        = "RestrictToApSouth1"
  description = "Only allow resources in ap-south-1 (except global services)"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyNonApSouth1"
      Effect = "Deny"
      NotAction = [
        "iam:*", "sts:*", "route53:*", "cloudfront:*",
        "waf:*", "support:*", "budgets:*", "ce:*",
        "organizations:*", "account:*"
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = "ap-south-1" }
      }
    }]
  })
}

# ── SCP 4: Deny root account usage ──────────────────────────────────────────
resource "aws_organizations_policy" "deny_root" {
  name        = "DenyRootAccountUsage"
  description = "Prevent use of the root account for any actions"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootAccount"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" }
      }
    }]
  })
}

# ── SCP 5: Require resource tags ────────────────────────────────────────────
resource "aws_organizations_policy" "require_tags" {
  name        = "RequireResourceTags"
  description = "Enforce Project and Environment tags on key resources"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RequireTags"
      Effect = "Deny"
      Action = ["ec2:RunInstances", "rds:CreateDBInstance", "eks:CreateCluster"]
      Resource = "*"
      Condition = {
        "Null" = {
          "aws:RequestTag/Project"     = "true"
          "aws:RequestTag/Environment" = "true"
        }
      }
    }]
  })
}

# ── Attach SCPs to OUs ───────────────────────────────────────────────────────
resource "aws_organizations_policy_attachment" "deny_public_s3_root" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "require_encryption_prod" {
  policy_id = aws_organizations_policy.require_encryption.id
  target_id = aws_organizations_organizational_unit.prod.id
}

resource "aws_organizations_policy_attachment" "restrict_regions_all" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "deny_root_all" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_policy_attachment" "require_tags_prod" {
  policy_id = aws_organizations_policy.require_tags.id
  target_id = aws_organizations_organizational_unit.prod.id
}

# ── Tag Policy ───────────────────────────────────────────────────────────────
resource "aws_organizations_policy" "tag_policy" {
  name        = "EstateFlowTagPolicy"
  description = "Enforce consistent tagging across all accounts"
  type        = "TAG_POLICY"
  content = jsonencode({
    tags = {
      Project     = { tag_value = { "@@assign" = ["EstateFlow-AI"] } }
      Environment = { tag_value = { "@@assign" = ["dev", "staging", "prod"] } }
      ManagedBy   = { tag_value = { "@@assign" = ["Terraform"] } }
    }
  })
}

output "organization_id" { value = aws_organizations_organization.main.id }
output "ou_ids" {
  value = {
    dev      = aws_organizations_organizational_unit.dev.id
    staging  = aws_organizations_organizational_unit.staging.id
    prod     = aws_organizations_organizational_unit.prod.id
    security = aws_organizations_organizational_unit.security.id
  }
}
