variable "project_name" {
  type    = string
  default = "estateflowai"
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "security_account_id" {
  type        = string
  description = "AWS Account ID for the Security account"
}
variable "management_account_id" {
  type        = string
  description = "AWS Account ID for the Management account"
}
