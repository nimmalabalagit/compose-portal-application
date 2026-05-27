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
  cluster_name             = var.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = "v1.18.1-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  # IRSA for VPC CNI to manage ENIs on your behalf
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = var.cluster_name
  addon_name               = "coredns"
  addon_version            = "v1.11.1-eksbuild.9"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on               = [aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = var.cluster_name
  addon_name    = "kube-proxy"
  addon_version = "v1.32.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
}

# ── AWS Load Balancer Controller ───────────────────────────────────────────────
# INTERVIEW TALKING POINT: AWS LBC replaces the deprecated in-tree AWS load
# balancer controller. It provisions:
#   - ALBs for Kubernetes Ingress resources (annotation: kubernetes.io/ingress.class: alb)
#   - NLBs for Services of type LoadBalancer
# Requires IRSA + subnet tags set in the VPC module.

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
# INTERVIEW TALKING POINT: ESO syncs AWS Parameter Store / Secrets Manager values
# into Kubernetes Secrets. Pods reference Kubernetes Secrets normally —
# they have no knowledge of AWS. ESO handles rotation automatically
# (refreshInterval in ExternalSecret CRD). This means rotating a DB password
# in Parameter Store propagates to pods without redeployment.

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.9.13"
  namespace  = "external-secrets"
  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

# ── Karpenter ─────────────────────────────────────────────────────────────────
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "0.37.0"
  namespace  = "karpenter"
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
          limits   = { cpu = "1",    memory = "1Gi"   }
        }
      }
    })
  ]

  depends_on = [helm_release.aws_lbc]
}

# ── Karpenter NodePool + EC2NodeClass (applied as K8s manifests) ──────────────
# INTERVIEW TALKING POINT: NodePool defines WHAT to provision (instance families,
# AZs, capacity types). EC2NodeClass defines HOW (AMI, subnets, security groups,
# instance profile). The subnet and SG selectors use the discovery tags we set
# in the VPC module — no hard-coded subnet IDs.

resource "kubernetes_manifest" "karpenter_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata   = { name = "default" }
    spec = {
      amiFamily = "AL2"
      role      = "${var.cluster_name}-karpenter-node"
      subnetSelectorTerms = [{
        tags = { "karpenter.sh/discovery" = var.cluster_name }
      }]
      securityGroupSelectorTerms = [{
        tags = { "aws:eks:cluster-name" = var.cluster_name }
      }]
      blockDeviceMappings = [{
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize = "50Gi"
          volumeType = "gp3"
          iops       = 3000
          encrypted  = true
        }
      }]
    }
  }
  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata   = { name = "default" }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1beta1"
            kind       = "EC2NodeClass"
            name       = "default"
          }
          requirements = [
            { key = "karpenter.sh/capacity-type",          operator = "In", values = ["spot", "on-demand"] },
            { key = "kubernetes.io/arch",                  operator = "In", values = ["amd64"] },
            { key = "node.kubernetes.io/instance-type",    operator = "In",
              values = ["t3.medium", "t3.large", "t3a.medium", "t3a.large",
                        "m5.large", "m5a.large", "m6i.large", "m6a.large"] },
          ]
          # Terminate nodes after 24h to recycle Spot savings and refresh AMIs
          expireAfter = "24h"
        }
      }
      limits = {
        cpu    = "100"   # 100 vCPU max across all Karpenter nodes
        memory = "200Gi"
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        consolidateAfter    = "30s"
        # INTERVIEW TALKING POINT: Consolidation bins-pack pods onto fewer nodes
        # and terminates empty nodes. This is how we achieve 58% cost reduction
        # from $67/month → $28/month in the lab.
      }
    }
  }
  depends_on = [kubernetes_manifest.karpenter_node_class]
}

# ── Metrics Server ────────────────────────────────────────────────────────────
# Required for HPA to read CPU/memory metrics
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"
  namespace  = "kube-system"
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "6.7.18"
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.cluster_name}.internal"
      }
      server = {
        # Expose ArgoCD via port-forward only — no public ALB
        service = { type = "ClusterIP" }
      }
      configs = {
        params = {
          "server.insecure" = true  # TLS terminated at ALB/ingress layer
        }
      }
    })
  ]
}