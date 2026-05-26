# modules/aurora-postgresql/main.tf
#
# INTERVIEW TALKING POINT — Aurora vs RDS PostgreSQL:
#   Aurora PostgreSQL: shared distributed storage (6-way replication across 3 AZs),
#     sub-10s failover, storage grows automatically, read replicas share same storage.
#   RDS PostgreSQL: block storage per instance, ~60-120s failover, storage pre-allocated.
#
# For EstateFlow AI we use Aurora PostgreSQL with 3 databases on the same cluster:
#   compose_users_db, compose_products_db, compose_orders_db
#   All accessed via the same cluster endpoint on port 5432.
#
# HPA POOL MATH (interview gold):
#   Aurora db.t3.medium: max_connections = LEAST(DBInstanceClassMemory/9531392, 5000)
#   db.t3.medium RAM = 4GB = 4,194,304 KB = 4,194,304 × 1024 bytes = 4,294,967,296 bytes
#   max_connections = floor(4,294,967,296 / 9,531,392) = 450
#   HikariCP default pool size per app = 10
#   Safe max replicas = floor(450 × 0.8 / services(4) / pool_size(10)) = floor(360/40) = 9
#   With 4 services × 9 replicas = 36 pods × 10 connections = 360 < 450 ✓

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.project_name}-${var.environment}-aurora-subnet-group" }
}

resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Aurora PostgreSQL — inbound from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS node group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids
    # INTERVIEW TALKING POINT: Use security group references (not CIDR) so the
    # rule auto-updates when new nodes are added. CIDR rules would require manual
    # updates every time node IPs change.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-aurora-sg" }
}

# Aurora cluster — uses a randomly generated master password stored in SSM
resource "random_password" "aurora_master" {
  length  = 32
  special = false  # Aurora password: no special chars to avoid shell escaping issues
}

resource "aws_ssm_parameter" "aurora_master_password" {
  name  = "/${var.project_name}/${var.environment}/db/master_password"
  type  = "SecureString"
  value = random_password.aurora_master.result
  tags  = { Purpose = "Aurora master password — managed by Terraform" }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier        = "${var.project_name}-${var.environment}-aurora"
  engine                    = "aurora-postgresql"
  engine_version            = "16.2"
  database_name             = "compose_users_db"  # Default DB; others created via Flyway
  master_username           = var.master_username
  master_password           = random_password.aurora_master.result
  db_subnet_group_name      = aws_db_subnet_group.aurora.name
  vpc_security_group_ids    = [aws_security_group.aurora.id]
  storage_encrypted         = true  # Required for SOC2 / HIPAA
  deletion_protection       = var.environment == "prod" ? true : false
  backup_retention_period   = var.environment == "prod" ? 7 : 1
  preferred_backup_window   = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  tags = { Name = "${var.project_name}-${var.environment}-aurora" }
}

resource "aws_rds_cluster_instance" "aurora" {
  count              = var.environment == "prod" ? 2 : 1  # 2 instances in prod (writer + reader)
  identifier         = "${var.project_name}-${var.environment}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
}