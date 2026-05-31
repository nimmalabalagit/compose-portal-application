variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "istio_version" {
  type        = string
  description = "Istio Helm chart version"
  default     = "1.20.3"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
