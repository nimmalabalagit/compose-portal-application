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

variable "bedrock_agent_id" {
  type        = string
  description = "Bedrock Agent ID (created via console first)"
  default     = ""
}

variable "bedrock_agent_alias" {
  type        = string
  description = "Bedrock Agent alias ID"
  default     = "TSTALIASID"
}

variable "argocd_url" {
  type    = string
  default = "https://argocd.estateflowai.co"
}

variable "slack_webhook_url" {
  type        = string
  sensitive   = true
  description = "Slack webhook URL for incident notifications"
}

variable "argocd_token" {
  type        = string
  sensitive   = true
  description = "ArgoCD API token for auto-rollback"
}
