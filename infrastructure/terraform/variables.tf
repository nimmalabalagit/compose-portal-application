# infrastructure/variables.tf

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Project identifier — used as prefix for all resource names"
  type        = string
  default     = "compose-portal"
}

# ── VPC ─────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block. Must not overlap with peered networks."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into. 3 AZs mandatory for production."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (EKS nodes, RDS, ElastiCache)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (ALB, NAT Gateway)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ── EKS ─────────────────────────────────────────────────────────────────────
variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for Karpenter NodePool (diversified for Spot)"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
}

variable "eks_min_nodes" {
  description = "Minimum nodes in managed node group (system pods only)"
  type        = number
  default     = 2
}

variable "eks_max_nodes" {
  description = "Maximum nodes (Karpenter provisioned separately)"
  type        = number
  default     = 10
}

# ── Database ────────────────────────────────────────────────────────────────
variable "db_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_master_username" {
  description = "Aurora master username (password injected via SSM)"
  type        = string
  default     = "compose_admin"
}

# ── Redis ────────────────────────────────────────────────────────────────────
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# ── Common ───────────────────────────────────────────────────────────────────
variable "tags" {
  description = "Additional tags to merge with default_tags"
  type        = map(string)
  default     = {}
}