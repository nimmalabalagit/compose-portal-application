# modules/aurora-postgresql/outputs.tf
output "cluster_endpoint"        { value = aws_rds_cluster.aurora.endpoint       sensitive = true }
output "reader_endpoint"         { value = aws_rds_cluster.aurora.reader_endpoint sensitive = true }
output "cluster_identifier"      { value = aws_rds_cluster.aurora.cluster_identifier }
output "master_password_ssm_arn" { value = aws_ssm_parameter.aurora_master_password.arn }