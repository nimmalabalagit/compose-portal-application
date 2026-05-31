variable "project_name"    { type = string; default = "estateflowai" }
variable "root_id"         { type = string }
variable "prod_ou_id"      { type = string }
variable "staging_ou_id"   { type = string }
variable "dev_ou_id"       { type = string }
variable "approved_regions" {
  type    = list(string)
  default = ["ap-south-1", "us-east-1", "eu-west-1"]
}
