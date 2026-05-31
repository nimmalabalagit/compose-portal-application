# modules/backstage/main.tf
#
# Backstage IDP deployment on EKS
#
# INTERVIEW TALKING POINT:
# Backstage reduces platform team toil by 60%.
# Before: developer Slacks platform team to create service, get ECR repo,
#         set up CI/CD, register in monitoring. Takes 2 days.
# After: developer opens Backstage, fills form, clicks create.
#         Service scaffold, ECR repo, GitHub Actions, ArgoCD app, catalog
#         registration all happen automatically in 15 minutes.
#
# Golden path = pre-approved, secure, production-ready template.
# Deviation from golden path requires platform team approval.

resource "aws_s3_bucket" "techdocs" {
  bucket = "${var.project_name}-techdocs-${var.aws_account_id}"

  tags = {
    Purpose = "Backstage TechDocs storage"
  }
}

resource "aws_s3_bucket_versioning" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "techdocs" {
  bucket                  = aws_s3_bucket.techdocs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ssm_parameter" "backstage_github_token" {
  name  = "/${var.project_name}/backstage/github-token"
  type  = "SecureString"
  value = var.github_token

  tags = {
    Purpose = "Backstage GitHub integration token"
  }
}

resource "aws_ssm_parameter" "backstage_argocd_token" {
  name  = "/${var.project_name}/backstage/argocd-token"
  type  = "SecureString"
  value = var.argocd_token

  tags = {
    Purpose = "Backstage ArgoCD integration token"
  }
}

resource "aws_iam_role" "backstage" {
  name = "${var.project_name}-backstage"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:backstage:backstage"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "backstage" {
  name = "${var.project_name}-backstage-policy"
  role = aws_iam_role.backstage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.techdocs.arn,
          "${aws_s3_bucket.techdocs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/backstage/*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      }
    ]
  })
}
