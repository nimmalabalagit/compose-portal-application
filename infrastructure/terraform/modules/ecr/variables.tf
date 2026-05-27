variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment (dev|prod)"
  type        = string
}

variable "services" {
  description = "List of service names to create ECR repos for"
  type        = list(string)
}
