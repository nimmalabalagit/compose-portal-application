# modules/eks-addons/main.tf
# Helm-based addons: EKS managed addons + Karpenter + LBC + ESO + ArgoCD + metrics-server
#
# INTERVIEW TALKING POINT: Two types of EKS addons:
#   1. EKS Managed Addons (aws_eks_addon resource): CoreDNS, kube-proxy, VPC CNI
#      → AWS manages upgrades, security patches
#   2. Helm-deployed addons: Karpenter, LBC, ArgoCD
#      → We manage version + values, but get Helm release management

# ── EKS Managed Addons ────────────────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.18.1-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = "v1.11.1-eksbuild.9"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on                  = [aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.32.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
}

# ── AWS Load Balancer Controller ───────────────────────────────────────────────
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lbc_irsa_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "replicaCount"
    value = "2"
  }
}

# ── External Secrets Operator ─────────────────────────────────────────────────
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.13"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

# ── Karpenter ─────────────────────────────────────────────────────────────────
resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.37.0"
  namespace        = "karpenter"
  create_namespace = true

  values = [
    yamlencode({
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = "${var.cluster_name}-karpenter-interruption"
        aws = {
          defaultInstanceProfile = "${var.cluster_name}-karpenter-node"
        }
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.karpenter_role_arn
        }
      }
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "1",    memory = "1Gi" }
        }
      }
    })
  ]

  depends_on = [helm_release.aws_lbc]
}

# NOTE: Karpenter NodePool + EC2NodeClass applied via kubectl AFTER cluster exists
# Files: k8s/karpenter/nodeclass-general.yaml + nodepool-general.yaml

# ── Metrics Server ────────────────────────────────────────────────────────────
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"
  namespace  = "kube-system"

  depends_on = [helm_release.aws_lbc]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "6.7.18"
  namespace        = "argocd"
  create_namespace = true
  depends_on       = [helm_release.aws_lbc]

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.cluster_name}.internal"
      }
      server = {
        service = { type = "ClusterIP" }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]
}
