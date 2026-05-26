# modules/elasticache-redis/main.tf
#
# INTERVIEW TALKING POINT — Redis use cases in EstateFlow AI:
#   1. API Gateway rate limiting: token bucket counter per IP (TTL = 60s)
#   2. User service cache: @Cacheable — user by UUID (TTL = 10min)
#   3. Product service cache: @Cacheable — product by ID (TTL = 5min)
#   4. Spring Session (if stateful session needed in future)
#
# Cluster mode disabled = single primary + optional replica.
# For production: enable cluster mode with 3 shards for horizontal scaling.

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "ElastiCache Redis — inbound from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids
    description     = "Redis from EKS node group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-redis-sg" }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "EstateFlow AI Redis — rate limiting and cache"
  node_type            = var.node_type
  num_cache_clusters   = var.environment == "prod" ? 2 : 1
  engine               = "redis"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true  # TLS in-transit — Spring Boot uses rediss:// URI
  automatic_failover_enabled  = var.environment == "prod" ? true : false

  tags = { Name = "${var.project_name}-${var.environment}-redis" }
}