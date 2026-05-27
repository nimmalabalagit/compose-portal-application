output "cluster_endpoint" {
  value     = aws_rds_cluster.aurora.endpoint
  sensitive = true
}

output "cluster_identifier" {
  value = aws_rds_cluster.aurora.cluster_identifier
}

output "master_password_ssm_path" {
  value = aws_ssm_parameter.aurora_master_password.name
}
