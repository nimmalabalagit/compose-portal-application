variable "project_name" {
  type    = string
  default = "estateflowai"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "aws_account_id" {
  type    = string
  default = "371056712467"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN for IRSA"
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC provider URL"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub token for Backstage integration"
}

variable "argocd_token" {
  type        = string
  sensitive   = true
  description = "ArgoCD API token for Backstage integration"
}
