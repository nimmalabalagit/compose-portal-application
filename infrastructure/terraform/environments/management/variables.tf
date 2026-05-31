variable "project_name"           { type = string; default = "estateflowai" }
variable "aws_region"             { type = string; default = "ap-south-1" }
variable "approved_regions"       { type = list(string); default = ["ap-south-1","us-east-1","eu-west-1"] }
variable "security_account_email" { type = string }
variable "dev_account_email"      { type = string }
variable "staging_account_email"  { type = string }
variable "prod_account_email"     { type = string }
