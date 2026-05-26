#!/bin/bash
# scripts/observability/install-grafana-stack.sh
# WHY Grafana OSS stack vs Datadog:
# Datadog: $27/host/month × 20 nodes = $540/month for infrastructure metrics only
# Add: APM $36/host = $720/month. Logs: $0.10/GB ingested.
# At 50GB/day logs: $150/day = $4,500/month. Total: ~$5,760/month
# Grafana OSS: compute only (EC2/EKS pods) = ~$260/month for 20 nodes
# Savings: $5,760 - $260 = $5,500/month = $66,000/year = 22× cheaper
# This is your "22× cheaper than CloudWatch" interview number:
# CloudWatch custom metrics: $0.30/metric/month × 500 metrics = $150/month
# Grafana Mimir running on EKS: ~$7/month (2 pods × m5.large spot)
# Savings ratio: $150 / $7 = 22×

set -euo pipefail

# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# ── Install Grafana Mimir (metrics storage) ──────────────────────────────────
# WHY Mimir over Thanos:
# Thanos requires a sidecar in every Prometheus pod.
# Mimir is a fully managed, remote-write compatible backend.
# Spring Boot → OTel → Mimir: simpler architecture, no Prometheus needed at all.
# Mimir uses S3 as backend storage — infinite retention for $0.023/GB.
# vs CloudWatch: $0.30/metric/month (no storage cost amortization)

helm install mimir grafana/mimir-distributed \
  --namespace observability \
  --create-namespace \
  --values - <<EOF
mimir:
  structuredConfig:
    common:
      storage:
        backend: s3
        s3:
          bucket_name: compose-portal-mimir-${AWS_ACCOUNT_ID}
          region: ap-south-1
          # WHY IRSA instead of access keys:
          # Same principle as GitHub Actions OIDC — no static credentials.
          # Mimir pod's service account has IRSA annotation → auto-gets S3 permissions.
          # No secret rotation needed.
    blocks_storage:
      s3:
        bucket_name: compose-portal-mimir-blocks-${AWS_ACCOUNT_ID}
    ruler_storage:
      s3:
        bucket_name: compose-portal-mimir-ruler-${AWS_ACCOUNT_ID}
    alertmanager_storage:
      s3:
        bucket_name: compose-portal-mimir-alertmanager-${AWS_ACCOUNT_ID}
alertmanager:
  enabled: true
store_gateway:
  zoneAwareReplication:
    enabled: false   # Single-AZ for dev/staging cost savings
compactor:
  resources:
    requests:
      memory: 512Mi
    limits:
      memory: 1Gi
EOF

# ── Install Grafana Loki (log aggregation) ───────────────────────────────────
# WHY Loki over ElasticSearch:
# ElasticSearch indexes ALL log content = expensive compute + storage.
# Loki only indexes labels (namespace, pod, app) and stores log content in S3 compressed.
# Query: you filter by labels first (fast + cheap), then search log content (grep-like).
# At 50GB/day: ElasticSearch needs ~500GB storage + 8-core indexing node = $800/month
# Loki on S3: $0.023/GB × 50 × 30 = $34.50/month = 22× cheaper

helm install loki grafana/loki \
  --namespace observability \
  --values - <<EOF
loki:
  auth_enabled: false
  storage:
    type: s3
    s3:
      region: ap-south-1
      bucketnames: compose-portal-loki-${AWS_ACCOUNT_ID}
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  limits_config:
    retention_period: 30d   # 30-day log retention (SOC2 requirement)
    ingestion_rate_mb: 50
    max_query_length: 2880h  # 120 days for historical queries
deploymentMode: SingleBinary   # Single pod for dev; use distributed mode for prod
singleBinary:
  replicas: 1
  resources:
    requests:
      memory: 512Mi
      cpu: 100m
    limits:
      memory: 1Gi
EOF

# ── Install Grafana Tempo (distributed tracing) ──────────────────────────────
helm install tempo grafana/tempo-distributed \
  --namespace observability \
  --values - <<EOF
storage:
  trace:
    backend: s3
    s3:
      bucket: compose-portal-tempo-${AWS_ACCOUNT_ID}
      region: ap-south-1
traces:
  otlp:
    grpc:
      enabled: true   # Spring Boot OTel → OTLP gRPC → Tempo
compactor:
  resources:
    requests:
      memory: 256Mi
ingester:
  replicas: 1
  resources:
    requests:
      memory: 512Mi
EOF

# ── Install Grafana UI ────────────────────────────────────────────────────────
helm install grafana grafana/grafana \
  --namespace observability \
  --values - <<EOF
adminPassword: "GrafanaAdmin@2026"   # Change in production via External Secrets
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Mimir
        type: prometheus
        url: http://mimir-nginx.observability.svc.cluster.local/prometheus
        isDefault: true
      - name: Loki
        type: loki
        url: http://loki.observability.svc.cluster.local:3100
      - name: Tempo
        type: tempo
        url: http://tempo.observability.svc.cluster.local:3100
persistence:
  enabled: true
  storageClassName: gp3
  size: 10Gi
EOF

echo "✅ Grafana stack installed"
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n observability svc/grafana 3000:80"
echo "  Open: http://localhost:3000 (admin / GrafanaAdmin@2026)"