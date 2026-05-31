variable "project_name" {
  type    = string
  default = "estateflowai"
}
variable "root_id" {
  type        = string
  description = "AWS Organizations root ID"
}
variable "prod_ou_id" {
  type        = string
  description = "Production OU ID"
}
variable "staging_ou_id" {
  type        = string
  description = "Staging OU ID"
}
variable "dev_ou_id" {
  type        = string
  description = "Dev OU ID"
}
variable "approved_regions" {
  type    = list(string)
  default = ["ap-south-1", "us-east-1", "eu-west-1"]
}
