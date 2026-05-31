output "techdocs_bucket" {
  value       = aws_s3_bucket.techdocs.id
  description = "TechDocs S3 bucket name"
}

output "backstage_role_arn" {
  value       = aws_iam_role.backstage.arn
  description = "Backstage IRSA role ARN"
}
