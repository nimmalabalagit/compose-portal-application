# infrastructure/outputs.tf
# These outputs are consumed by CI/CD pipelines and referenced in runbooks.

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name — used in kubectl and CI/CD"
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "ECR repo URLs keyed by service name"
  value       = module.ecr.repository_urls
}

output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
  sensitive   = true  # contains DB hostname — never log in CI
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter-provisioned nodes"
  value       = module.eks_cluster.karpenter_node_role_arn
}

output "irsa_role_arns" {
  description = "Map of service name → IRSA role ARN"
  value       = module.iam_roles.service_role_arns
}