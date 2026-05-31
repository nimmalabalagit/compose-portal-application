output "global_cluster_id" {
  value       = aws_rds_global_cluster.estateflowai.id
  description = "Aurora Global Database cluster ID"
}

output "primary_cluster_endpoint" {
  value       = aws_rds_cluster.primary.endpoint
  description = "Primary Aurora cluster endpoint ap-south-1"
}

output "secondary_cluster_endpoint" {
  value       = aws_rds_cluster.secondary.endpoint
  description = "DR Aurora cluster endpoint us-east-1"
}

output "health_check_id" {
  value       = aws_route53_health_check.primary_api.id
  description = "Route53 health check ID for primary API"
}

output "dr_test_lambda_arn" {
  value       = aws_lambda_function.dr_test.arn
  description = "DR test Lambda function ARN"
}
