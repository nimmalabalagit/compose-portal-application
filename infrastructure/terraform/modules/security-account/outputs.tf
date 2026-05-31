output "guardduty_detector_id"   { value = aws_guardduty_detector.security_account.id }
output "cloudtrail_bucket_name"  { value = aws_s3_bucket.cloudtrail.id }
output "cloudtrail_kms_key_arn"  { value = aws_kms_key.cloudtrail.arn }
output "cloudtrail_arn"          { value = aws_cloudtrail.organization.arn }
