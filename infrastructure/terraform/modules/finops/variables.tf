variable "project_name" {
  type    = string
  default = "estateflowai"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "aws_account_id" {
  type    = string
  default = "371056712467"
}

variable "kubecost_version" {
  type    = string
  default = "2.3.4"
}

variable "kubecost_token" {
  type        = string
  description = "Kubecost token from kubecost.com (free tier available)"
  default     = ""
}

variable "monthly_budget_usd" {
  type        = string
  description = "Monthly budget limit in USD"
  default     = "200"
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses for budget alerts"
  default     = ["nbalakrishna.devops@gmail.com"]
}

variable "alert_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for cost alerts"
}
