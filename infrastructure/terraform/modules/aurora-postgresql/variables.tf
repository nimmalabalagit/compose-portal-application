variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "master_username" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "allowed_sg_ids" {
  type = list(string)
}

variable "aws_account_id" {
  type = string
}
