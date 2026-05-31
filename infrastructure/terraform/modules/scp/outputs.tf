output "deny_regions_policy_id"  { value = aws_organizations_policy.deny_non_approved_regions.id }
output "deny_security_policy_id" { value = aws_organizations_policy.deny_disable_security.id }
output "deny_root_policy_id"     { value = aws_organizations_policy.deny_root.id }
output "enforce_encryption_id"   { value = aws_organizations_policy.enforce_encryption.id }
