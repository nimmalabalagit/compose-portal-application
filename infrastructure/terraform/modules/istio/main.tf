# modules/istio/main.tf
# Installs Istio on EKS via Helm
#
# INTERVIEW: Istio adds mTLS between all pods automatically.
# Without Istio: order-service calls user-service over plain HTTP.
# With Istio: every pod-to-pod call is TLS 1.3, cert rotated every 24hr.
# No code changes in Spring Boot needed — Envoy sidecar handles it.
#
# Oracle analogy: Oracle Network Encryption (sqlnet.ora ENCRYPTION_SERVER=REQUIRED)
# encrypts all DB connections without application code changes.

resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_version
  namespace        = "istio-system"
  create_namespace = true

  set {
    name  = "defaultRevision"
    value = "default"
  }

  timeout = 300
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }

  set {
    name  = "meshConfig.enableTracing"
    value = "true"
  }

  set {
    name  = "meshConfig.defaultConfig.tracing.zipkin.address"
    value = "otel-collector.observability.svc.cluster.local:9411"
  }

  set {
    name  = "meshConfig.outboundTrafficPolicy.mode"
    value = "REGISTRY_ONLY"
  }

  values = [
    yamlencode({
      pilot = {
        resources = {
          requests = { cpu = "100m", memory = "256Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }
    })
  ]

  depends_on = [helm_release.istio_base]
  timeout    = 300
}

resource "kubernetes_namespace" "compose_portal_istio" {
  metadata {
    name = "compose-portal"
    labels = {
      "istio-injection" = "enabled"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}
