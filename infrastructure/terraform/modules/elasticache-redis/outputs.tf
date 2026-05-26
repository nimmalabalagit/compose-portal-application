# modules/elasticache-redis/outputs.tf
output "primary_endpoint" {
  value     = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive = true
}
output "port" { value = 6379 }