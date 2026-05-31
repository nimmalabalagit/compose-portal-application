# modules/disaster-recovery/main.tf
#
# Disaster Recovery — Pilot Light Strategy
# RTO: 30 minutes | RPO: 5 minutes
# Primary: ap-south-1 | DR: us-east-1
#
# INTERVIEW: DR tiers:
#   Backup/Restore: RTO 4hr  | RPO 1hr  | Cost +$2/day
#   Pilot Light:    RTO 30min| RPO 5min | Cost +$8/day  <- WE USE THIS
#   Warm Standby:   RTO 5min | RPO 1min | Cost +$40/day
#   Multi-Site:     RTO 0    | RPO 0    | Cost +$200/day
#
# Oracle analogy:
#   Pilot Light = Oracle Data Guard in MOUNT state
#   Warm Standby = Oracle Data Guard READ ONLY open
#   Multi-Site = Oracle Active Data Guard

resource "aws_rds_global_cluster" "estateflowai" {
  global_cluster_identifier = "${var.project_name}-global"
  engine                    = "aurora-postgresql"
  engine_version            = "16.4"
  database_name             = "compose_portal"
  deletion_protection       = var.deletion_protection

  tags = {
    Purpose    = "Aurora Global Database — primary ap-south-1, DR us-east-1"
    RTO        = "30min"
    RPO        = "5min"
    Compliance = "SOC2-A1.2"
  }
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "${var.project_name}-primary"
  engine                    = "aurora-postgresql"
  engine_version            = "16.4"
  global_cluster_identifier = aws_rds_global_cluster.estateflowai.id
  db_subnet_group_name      = var.primary_subnet_group_name
  vpc_security_group_ids    = var.primary_security_group_ids
  master_username           = var.db_master_username
  manage_master_user_password = true
  storage_encrypted         = true
  kms_key_id                = var.kms_key_arn
  backup_retention_period   = 7
  preferred_backup_window   = "02:00-03:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-primary-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  provider = aws.primary

  tags = {
    Role   = "primary"
    Region = "ap-south-1"
  }
}

resource "aws_rds_cluster" "secondary" {
  cluster_identifier        = "${var.project_name}-dr"
  engine                    = "aurora-postgresql"
  engine_version            = "16.4"
  global_cluster_identifier = aws_rds_global_cluster.estateflowai.id
  db_subnet_group_name      = var.dr_subnet_group_name
  vpc_security_group_ids    = var.dr_security_group_ids
  storage_encrypted         = true
  kms_key_id                = var.dr_kms_key_arn
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-dr-final-snapshot"

  provider   = aws.dr
  depends_on = [aws_rds_cluster.primary]

  tags = {
    Role   = "secondary"
    Region = "us-east-1"
  }
}

resource "aws_ecr_replication_configuration" "dr" {
  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = var.dr_account_id
      }
      repository_filter {
        filter      = "${var.project_name}/*"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
  provider = aws.primary
}

resource "aws_route53_health_check" "primary_api" {
  fqdn              = "api.estateflowai.co"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/actuator/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name    = "${var.project_name}-primary-health-check"
    Purpose = "Monitors primary ALB for automatic DNS failover"
  }
}

resource "aws_route53_record" "api_primary" {
  zone_id = var.hosted_zone_id
  name    = "api.estateflowai.co"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_api.id

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_secondary" {
  zone_id = var.hosted_zone_id
  name    = "api.estateflowai.co"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  alias {
    name                   = var.dr_alb_dns
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudwatch_event_rule" "dr_test" {
  name                = "${var.project_name}-quarterly-dr-test"
  description         = "Quarterly automated DR test"
  schedule_expression = "cron(0 2 1 */3 ? *)"

  tags = {
    Purpose    = "Quarterly DR test"
    Compliance = "SOC2-A1.2"
  }
}

resource "aws_cloudwatch_event_target" "dr_test_lambda" {
  rule = aws_cloudwatch_event_rule.dr_test.name
  arn  = aws_lambda_function.dr_test.arn
}

resource "aws_iam_role" "dr_test_lambda" {
  name = "${var.project_name}-dr-test-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dr_test_lambda" {
  name = "${var.project_name}-dr-test-policy"
  role = aws_iam_role.dr_test_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:DescribeImages",
        "secretsmanager:GetSecretValue",
        "sns:Publish",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "rds:DescribeDBClusters",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "dr_test" {
  function_name    = "${var.project_name}-dr-test"
  role             = aws_iam_role.dr_test_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 300
  filename         = data.archive_file.dr_test.output_path
  source_code_hash = data.archive_file.dr_test.output_base64sha256

  environment {
    variables = {
      DR_CLUSTER_ENDPOINT = aws_rds_cluster.secondary.endpoint
      DR_REGION           = var.dr_region
      SNS_TOPIC_ARN       = var.alert_sns_topic_arn
      PROJECT_NAME        = var.project_name
    }
  }
}

data "archive_file" "dr_test" {
  type        = "zip"
  output_path = "/tmp/dr_test.zip"

  source {
    content  = "def handler(event, context): return {'status': 'DR test placeholder'}"
    filename = "index.py"
  }
}
