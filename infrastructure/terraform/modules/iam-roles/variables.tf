variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "eks_namespace" {
  type    = string
  default = "compose-portal"
}

# This is what main.tf iterates over with for_each
# Key   = Kubernetes ServiceAccount name
# Value = Kubernetes namespace that ServiceAccount lives in
variable "service_accounts" {
  description = "Map of ServiceAccount name to namespace for IRSA trust policies"
  type        = map(string)
  default = {
    "gateway-service"              = "compose-portal"
    "user-service"                 = "compose-portal"
    "product-service"              = "compose-portal"
    "order-service"                = "compose-portal"
    "aws-load-balancer-controller" = "kube-system"
    "external-secrets"             = "external-secrets"
  }
}
