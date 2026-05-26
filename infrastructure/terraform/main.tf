# infrastructure/main.tf
# Root module: orchestrates all child modules in dependency order.
# Module outputs are passed as inputs to downstream modules —
# no hard-coded ARNs or IDs anywhere.

# ── 1. VPC ───────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

# ── 2. ECR Repositories ──────────────────────────────────────────────────────
# ECR is created before EKS so CI can push images before cluster exists.
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  services     = ["gateway-service", "user-service", "product-service", "order-service", "frontend"]
}

# ── 3. EKS Cluster ───────────────────────────────────────────────────────────
module "eks_cluster" {
  source = "./modules/eks-cluster"

  project_name        = var.project_name
  environment         = var.environment
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_instance_types = var.eks_node_instance_types
  min_nodes           = var.eks_min_nodes
  max_nodes           = var.eks_max_nodes
  aws_account_id      = data.aws_caller_identity.current.account_id
}

# ── 4. IAM Roles (IRSA) ───────────────────────────────────────────────────────
# IRSA maps Kubernetes ServiceAccounts → IAM Roles via OIDC federation.
# No node-level IAM permissions needed for application workloads.
module "iam_roles" {
  source = "./modules/iam-roles"

  project_name          = var.project_name
  environment           = var.environment
  aws_account_id        = data.aws_caller_identity.current.account_id
  oidc_provider_arn     = module.eks_cluster.oidc_provider_arn
  oidc_provider_url     = module.eks_cluster.oidc_provider_url
  eks_namespace         = "compose-portal"
}

# ── 5. Aurora PostgreSQL ───────────────────────────────────────────────────────
module "aurora" {
  source = "./modules/aurora-postgresql"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  master_username    = var.db_master_username
  db_instance_class  = var.db_instance_class
  # EKS nodes SG allowed to connect to RDS
  allowed_sg_ids     = [module.eks_cluster.node_security_group_id]
  aws_account_id     = data.aws_caller_identity.current.account_id
}

# ── 6. ElastiCache Redis ───────────────────────────────────────────────────────
module "redis" {
  source = "./modules/elasticache-redis"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  node_type      = var.redis_node_type
  allowed_sg_ids = [module.eks_cluster.node_security_group_id]
}

# ── 7. EKS Addons (Helm charts) ───────────────────────────────────────────────
# Depends on EKS cluster + IAM roles existing first.
module "eks_addons" {
  source = "./modules/eks-addons"

  project_name              = var.project_name
  environment               = var.environment
  cluster_name              = module.eks_cluster.cluster_name
  cluster_endpoint          = module.eks_cluster.cluster_endpoint
  aws_account_id            = data.aws_caller_identity.current.account_id
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  lbc_irsa_role_arn         = module.iam_roles.lbc_role_arn
  external_secrets_role_arn = module.iam_roles.external_secrets_role_arn
  karpenter_role_arn        = module.eks_cluster.karpenter_node_role_arn

  depends_on = [module.eks_cluster, module.iam_roles]
}