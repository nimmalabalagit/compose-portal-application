variable "project_name" {
  type    = string
  default = "estateflowai"
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "approved_regions" {
  type    = list(string)
  default = ["ap-south-1", "us-east-1", "eu-west-1"]
}
variable "security_account_email" {
  type        = string
  description = "Unique email for Security account"
}
variable "dev_account_email" {
  type        = string
  description = "Unique email for Dev account"
}
variable "staging_account_email" {
  type        = string
  description = "Unique email for Staging account"
}
variable "prod_account_email" {
  type        = string
  description = "Unique email for Production account"
}
