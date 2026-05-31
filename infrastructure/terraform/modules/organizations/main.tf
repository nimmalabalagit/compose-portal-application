resource "aws_organizations_organization" "this" {
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY", "BACKUP_POLICY"]
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com", "config.amazonaws.com",
    "guardduty.amazonaws.com",  "securityhub.amazonaws.com",
    "sso.amazonaws.com",        "ram.amazonaws.com",
    "compute-optimizer.amazonaws.com", "inspector2.amazonaws.com",
  ]
}
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}
resource "aws_organizations_organizational_unit" "dev" {
  name      = "Dev"
  parent_id = aws_organizations_organization.this.roots[0].id
}
resource "aws_organizations_organizational_unit" "staging" {
  name      = "Staging"
  parent_id = aws_organizations_organization.this.roots[0].id
}
resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organization.this.roots[0].id
}
resource "aws_organizations_account" "security" {
  name  = "${var.project_name}-security"
  email = var.security_account_email
  parent_id = aws_organizations_organizational_unit.security.id
  iam_user_access_to_billing = "ALLOW"
  lifecycle { ignore_changes = [iam_user_access_to_billing] }
}
resource "aws_organizations_account" "dev" {
  name  = "${var.project_name}-dev"
  email = var.dev_account_email
  parent_id = aws_organizations_organizational_unit.dev.id
  iam_user_access_to_billing = "ALLOW"
  lifecycle { ignore_changes = [iam_user_access_to_billing] }
}
resource "aws_organizations_account" "staging" {
  name  = "${var.project_name}-staging"
  email = var.staging_account_email
  parent_id = aws_organizations_organizational_unit.staging.id
  iam_user_access_to_billing = "ALLOW"
  lifecycle { ignore_changes = [iam_user_access_to_billing] }
}
resource "aws_organizations_account" "prod" {
  name  = "${var.project_name}-prod"
  email = var.prod_account_email
  parent_id = aws_organizations_organizational_unit.prod.id
  iam_user_access_to_billing = "ALLOW"
  lifecycle { ignore_changes = [iam_user_access_to_billing] }
}
resource "aws_organizations_delegated_administrator" "guardduty" {
  account_id = aws_organizations_account.security.id
  service_principal = "guardduty.amazonaws.com"
}
resource "aws_organizations_delegated_administrator" "security_hub" {
  account_id = aws_organizations_account.security.id
  service_principal = "securityhub.amazonaws.com"
}
resource "aws_organizations_delegated_administrator" "inspector" {
  account_id = aws_organizations_account.security.id
  service_principal = "inspector2.amazonaws.com"
}
