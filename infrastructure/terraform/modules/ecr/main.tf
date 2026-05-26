# modules/ecr/main.tf
#
# INTERVIEW TALKING POINT — ECR best practices at interview level:
#   1. IMMUTABLE tags: prevents accidental overwrites of :latest in production.
#      CI always pushes by SHA tag — never mutable :latest.
#   2. Lifecycle policies: auto-delete untagged images > 1 day old (builds that failed).
#      Keep only last 10 tagged versions per repo.
#   3. ECR Enhanced Scanning: uses AWS Inspector to scan on push + continuously.
#      Block deployments if CRITICAL CVE found (enforced in CI via policy).
#   4. Cross-account access: production clusters pull from a single ECR account
#      via resource-based policy (not IAM inline policies).

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"  # Prevents :latest overwrite

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"  # Default is AES256; KMS gives audit trail
  }

  tags = { Service = each.value }
}

# Lifecycle policy: clean up old images automatically
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 1 day (failed builds)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}