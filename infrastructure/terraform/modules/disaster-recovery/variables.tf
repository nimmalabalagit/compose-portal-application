variable "project_name" {
  type    = string
  default = "estateflowai"
}

variable "primary_region" {
  type    = string
  default = "ap-south-1"
}

variable "dr_region" {
  type    = string
  default = "us-east-1"
}

variable "dr_account_id" {
  type    = string
  default = "371056712467"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "db_master_username" {
  type    = string
  default = "compose_admin"
}

variable "kms_key_arn" {
  type = string
}

variable "dr_kms_key_arn" {
  type = string
}

variable "primary_subnet_group_name" {
  type = string
}

variable "primary_security_group_ids" {
  type = list(string)
}

variable "dr_subnet_group_name" {
  type = string
}

variable "dr_security_group_ids" {
  type = list(string)
}

variable "hosted_zone_id" {
  type = string
}

variable "primary_alb_dns" {
  type = string
}

variable "primary_alb_zone_id" {
  type = string
}

variable "dr_alb_dns" {
  type = string
}

variable "dr_alb_zone_id" {
  type = string
}

variable "alert_sns_topic_arn" {
  type = string
}
