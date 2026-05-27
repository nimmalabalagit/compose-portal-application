variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "lbc_irsa_role_arn" {
  type = string
}

variable "external_secrets_role_arn" {
  type = string
}

variable "karpenter_role_arn" {
  type = string
}
