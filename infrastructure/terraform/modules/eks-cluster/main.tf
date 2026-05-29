# modules/eks-cluster/main.tf
#
# INTERVIEW TALKING POINT: EKS cluster IAM vs node IAM are separate concerns:
#   - Cluster IAM role: allows the EKS control plane to call AWS APIs on your behalf
#   - Node IAM role:    allows EC2 worker nodes to join the cluster + pull ECR images
#   - IRSA:            allows specific pods to assume specific IAM roles (fine-grained)
# Never attach application permissions to the node IAM role - use IRSA.

locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

# ── EKS Cluster IAM Role ──────────────────────────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── EKS Control Plane ─────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true   # Nodes communicate with API server internally
    endpoint_public_access  = true   # kubectl from dev laptops (restrict to corporate IP in prod)
    public_access_cidrs     = ["0.0.0.0/0"]  # Restrict to VPN CIDR in production
  }

  # Enable envelope encryption for Kubernetes Secrets using a CMK
  # INTERVIEW TALKING POINT: Without this, Kubernetes Secrets are base64 in etcd - NOT encrypted.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  # Cluster logging to CloudWatch - required for SOC2 audit trail
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = { Name = local.cluster_name }
}

# KMS key for Secrets encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "EKS Secrets encryption for ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# ── OIDC Provider (required for IRSA) ────────────────────────────────────────
# INTERVIEW TALKING POINT: IRSA works via OIDC federation:
#   1. EKS cluster exposes an OIDC issuer URL
#   2. Kubernetes projects a JWT token into the pod at a known path
#   3. Pod's JWT contains sub = system:serviceaccount:<ns>:<sa>
#   4. IAM role trust policy allows specific sub claims to assume the role
#   5. AWS SDK in the pod automatically calls sts:AssumeRoleWithWebIdentity

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ── Node IAM Role ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "eks_nodes" {
  name = "${local.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ── Managed Node Group (system / bootstrap nodes) ─────────────────────────────
# INTERVIEW TALKING POINT: We use a small managed node group for system pods
# (CoreDNS, kube-proxy, metrics-server, Karpenter controller itself).
# Application workloads land on Karpenter-provisioned Spot nodes.
# Karpenter cannot provision nodes for itself - bootstrap chicken-and-egg.

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-system"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.medium"]
  capacity_type   = "ON_DEMAND"  # System nodes: ON_DEMAND only - no interruptions

  scaling_config {
    desired_size = var.min_nodes
    min_size     = var.min_nodes
    max_size     = var.max_nodes
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]
}

# ── Node Security Group (export for RDS/Redis SG rules) ──────────────────────
# EKS creates a cluster SG and a node SG automatically.
# We export the node SG ID so RDS and ElastiCache can allow inbound from nodes.

