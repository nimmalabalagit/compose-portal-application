variable "project_name" {
  type    = string
  default = "estateflowai"
}
variable "security_account_email" {
  type        = string
  description = "Email for Security account"
}
variable "dev_account_email" {
  type        = string
  description = "Email for Dev account"
}
variable "staging_account_email" {
  type        = string
  description = "Email for Staging account"
}
variable "prod_account_email" {
  type        = string
  description = "Email for Production account"
}
