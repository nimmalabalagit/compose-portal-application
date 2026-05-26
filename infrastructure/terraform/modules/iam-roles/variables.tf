# modules/iam-roles/variables.tf
variable "project_name"      { type = string }
variable "environment"       { type = string }
variable "aws_account_id"    { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "eks_namespace"     { type = string }
variable "aws_region"        { type = string default = "ap-south-1" }

variable "service_accounts" {
  description = "Map of ServiceAccount name → namespace for IRSA trust policies"
  type        = map(string)
  default = {
    "gateway-service"               = "compose-portal"
    "user-service"                  = "compose-portal"
    "product-service"               = "compose-portal"
    "order-service"                 = "compose-portal"
    "aws-load-balancer-controller"  = "kube-system"
    "external-secrets"              = "external-secrets"
  }
}