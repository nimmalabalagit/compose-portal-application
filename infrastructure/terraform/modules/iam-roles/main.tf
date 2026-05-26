# modules/iam-roles/main.tf
#
# INTERVIEW TALKING POINT — IRSA trust policy anatomy:
#   The trust policy says: "Allow the OIDC provider to assume this role,
#   but ONLY when the token's sub claim equals
#   system:serviceaccount:<namespace>:<service-account-name>"
#
# This ensures that ONLY the specific pod's ServiceAccount can assume the role.
# Even if a pod with a different ServiceAccount is running in the same namespace,
# it cannot assume this role. This is pod-level IAM isolation without node-level
# permissions.

locals {
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")
}

# ── IRSA helper: builds trust policy for a given ServiceAccount ───────────────
data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = var.service_accounts  # map of { sa_name → namespace }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${each.value}:${each.key}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── gateway-service: needs SSM Parameter Store read access ────────────────────
resource "aws_iam_role" "gateway" {
  name               = "${var.project_name}-${var.environment}-gateway-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["gateway-service"].json
}

resource "aws_iam_role_policy" "gateway_ssm" {
  name = "ssm-parameter-read"
  role = aws_iam_role.gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      # Least privilege: only /compose-portal/<env>/gateway/* parameters
      Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/gateway/*"
    }]
  })
}

# ── user-service: SSM + Cognito read for token validation ─────────────────────
resource "aws_iam_role" "user_service" {
  name               = "${var.project_name}-${var.environment}-user-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["user-service"].json
}

resource "aws_iam_role_policy" "user_service_ssm" {
  name = "ssm-parameter-read"
  role = aws_iam_role.user_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/user/*"
    }]
  })
}

# ── product-service: SSM access ───────────────────────────────────────────────
resource "aws_iam_role" "product_service" {
  name               = "${var.project_name}-${var.environment}-product-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["product-service"].json
}

resource "aws_iam_role_policy" "product_service_ssm" {
  name = "ssm-parameter-read"
  role = aws_iam_role.product_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/product/*"
    }]
  })
}

# ── order-service: SSM + SNS publish ─────────────────────────────────────────
resource "aws_iam_role" "order_service" {
  name               = "${var.project_name}-${var.environment}-order-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["order-service"].json
}

resource "aws_iam_role_policy" "order_service" {
  name = "ssm-and-sns"
  role = aws_iam_role.order_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/order/*"
      },
      {
        # order-service publishes to SNS when order state transitions
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.project_name}-${var.environment}-order-events"
      }
    ]
  })
}

# ── AWS LBC IRSA ──────────────────────────────────────────────────────────────
resource "aws_iam_role" "aws_lbc" {
  name               = "${var.project_name}-${var.environment}-aws-lbc-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["aws-load-balancer-controller"].json
}

# AWS provides the managed policy for LBC — it's well-maintained and comprehensive
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_lbc" {
  name   = "${var.project_name}-${var.environment}-aws-lbc-policy"
  policy = data.http.lbc_policy.response_body
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  role       = aws_iam_role.aws_lbc.name
  policy_arn = aws_iam_policy.aws_lbc.arn
}

# ── External Secrets Operator IRSA ────────────────────────────────────────────
resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-${var.environment}-external-secrets-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume_role["external-secrets"].json
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "parameter-store-read"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:DescribeParameters",
      ]
      # ESO accesses all compose-portal parameters — scoped to project
      Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/*"
    }]
  })
}