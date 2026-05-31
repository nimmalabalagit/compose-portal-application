# SCP 1 — Deny non-approved regions
resource "aws_organizations_policy" "deny_non_approved_regions" {
  name        = "${var.project_name}-deny-non-approved-regions"
  description = "Allow only ap-south-1, us-east-1, eu-west-1"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyNonApprovedRegions"
      Effect = "Deny"
      NotAction = [
        "iam:*","sts:*","support:*","billing:*","budgets:*",
        "ce:*","organizations:*","cloudfront:*","route53:*",
        "route53domains:*","waf:*","account:*","health:*",
      ]
      Resource  = "*"
      Condition = { StringNotEquals = { "aws:RequestedRegion" = var.approved_regions } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_regions_root" {
  policy_id = aws_organizations_policy.deny_non_approved_regions.id
  target_id = var.root_id
}

# SCP 2 — Deny disabling security services
resource "aws_organizations_policy" "deny_disable_security" {
  name        = "${var.project_name}-deny-disable-security"
  description = "Prevent disabling CloudTrail, GuardDuty, Security Hub, Config"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisableCloudTrail"
        Effect = "Deny"
        Action = ["cloudtrail:DeleteTrail","cloudtrail:StopLogging","cloudtrail:UpdateTrail"]
        Resource = "*"
      },
      {
        Sid    = "DenyDisableGuardDuty"
        Effect = "Deny"
        Action = ["guardduty:DeleteDetector","guardduty:DisassociateFromMasterAccount","guardduty:StopMonitoringMembers"]
        Resource = "*"
      },
      {
        Sid    = "DenyDisableSecurityHub"
        Effect = "Deny"
        Action = ["securityhub:DeleteHub","securityhub:DisableSecurityHub","securityhub:DisassociateFromMasterAccount"]
        Resource = "*"
      },
      {
        Sid    = "DenyDisableConfig"
        Effect = "Deny"
        Action = ["config:DeleteConfigurationRecorder","config:StopConfigurationRecorder"]
        Resource = "*"
      }
    ]
  })
}
resource "aws_organizations_policy_attachment" "deny_disable_security_root" {
  policy_id = aws_organizations_policy.deny_disable_security.id
  target_id = var.root_id
}

# SCP 3 — Deny leaving organization
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "${var.project_name}-deny-leave-organization"
  description = "Prevent member accounts from leaving the Organization"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Sid      = "DenyLeaveOrg"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }]
  })
}
resource "aws_organizations_policy_attachment" "deny_leave_org_root" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = var.root_id
}

# SCP 4 — Deny root account usage in prod/staging
resource "aws_organizations_policy" "deny_root" {
  name        = "${var.project_name}-deny-root-account"
  description = "Deny all actions by root user in member accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootAccountActions"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = { StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_root_prod" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = var.prod_ou_id
}
resource "aws_organizations_policy_attachment" "deny_root_staging" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = var.staging_ou_id
}

# SCP 5 — Enforce encryption at rest
resource "aws_organizations_policy" "enforce_encryption" {
  name        = "${var.project_name}-enforce-encryption"
  description = "Deny unencrypted RDS and EBS in prod/staging"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedRDS"
        Effect = "Deny"
        Action = ["rds:CreateDBInstance","rds:CreateDBCluster"]
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
resource "aws_organizations_policy_attachment" "enforce_encryption_prod" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = var.prod_ou_id
}
resource "aws_organizations_policy_attachment" "enforce_encryption_staging" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = var.staging_ou_id
}
