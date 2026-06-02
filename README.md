# EstateFlow AI — Cloud-Native Microservices Platform
## Production-Grade AWS DevOps Portfolio | EKS 1.32 | GitOps | AIOps | Istio | Terraform

<div align="center">

![Platform Status](https://img.shields.io/badge/Platform-Live-brightgreen?style=for-the-badge&logo=amazonaws)
![EKS Version](https://img.shields.io/badge/EKS-v1.32-orange?style=for-the-badge&logo=kubernetes)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.2.3-green?style=for-the-badge&logo=springboot)
![Terraform](https://img.shields.io/badge/Terraform-97_Resources-purple?style=for-the-badge&logo=terraform)
![ArgoCD](https://img.shields.io/badge/ArgoCD-Synced_%26_Healthy-blue?style=for-the-badge&logo=argo)

**Live:** [estateflowai.co](https://www.estateflowai.co) | **API:** [api.estateflowai.co/actuator/health](https://api.estateflowai.co/actuator/health) | **Grafana:** [grafana.estateflowai.co](https://grafana.estateflowai.co)

</div>

---

## What This Is

EstateFlow AI is a **production-grade, cloud-native microservices platform** built to demonstrate Principal-level AWS DevOps engineering. It runs 4 Spring Boot 3.2.3 microservices on Amazon EKS 1.32 in ap-south-1 — fully automated via GitOps, secured with defence-in-depth, and operated by an AIOps Lambda agent.

> **This is not a tutorial project.** Every component is live and load-tested. 13 real production bugs were encountered and fixed during build — each documented as an interview story.

---

## Live Platform Architecture

```
INTERNET
    │ HTTPS TLS 1.3 (ACM wildcard *.estateflowai.co)
    ▼
Route53 DNS → Application Load Balancer
    │ (AWS Load Balancer Controller — Ingress → ALB)
    ▼
EKS 1.32 — 3 nodes across 3 AZs (ap-south-1a/b/c)
    │
    ├── frontend          React 18 + Nginx          → www.estateflowai.co
    ├── gateway-service   Spring Boot 8080           → api.estateflowai.co
    │   ├── Rate Limiter  Redis token bucket (100/min/IP)
    │   ├── Circuit Breaker  Resilience4j per route
    │   └── Istio PERMISSIVE mTLS → downstream
    ├── user-service      Spring Boot 8081
    │   └── Aurora PostgreSQL → users_db
    ├── product-service   Spring Boot 8082
    │   └── Aurora PostgreSQL → products_db + Redis cache (5min TTL)
    └── order-service     Spring Boot 8083
        ├── Aurora PostgreSQL → orders_db
        ├── DocumentDB → orders_audit (immutable, TLS)
        ├── RabbitMQ → order events
        └── SNS → SQS → Lambda (async CDK stack)

OBSERVABILITY:  OTel DaemonSet → Prometheus → Grafana (grafana.estateflowai.co)
SECURITY:       GuardDuty + Security Hub (FSBP+CIS) + Inspector v2 + CloudTrail + Config
AIOPS:          CloudWatch Alarm → EventBridge → Lambda RCA (208ms, MTTR 3 min)
GITOPS:         GitHub Actions 7 jobs → ArgoCD selfHeal → EKS rolling update
IAC:            Terraform 97 resources (8 modules) + AWS CDK Python
DR:             ECR cross-region replication + Route53 health check auto-failover
FINOPS:         AWS Budgets $40/month + Cost Anomaly Detection + Karpenter Spot (70% saving)
```

---

## Platform Metrics

| Metric | Value |
|--------|-------|
| Pipeline: git push → pod running | **8 minutes** |
| Load test RPS | **26.4 RPS** |
| Load test P95 latency | **163ms** |
| Error rate | **0.33%** |
| MTTR (AIOps Lambda) | **3 minutes** (was 47 min) |
| Terraform resources | **97 live** |
| Compute cost saving | **70%** (Karpenter Spot) |
| Cost per 1,000 requests | **$0.0051** |
| Daily platform cost | **$11.69** |
| SSM parameters | **21** |
| Security Hub CVEs (unique) | **13** |
| GuardDuty threats | **0** |

---

## Live Endpoints

| URL | What It Shows |
|-----|--------------|
| https://www.estateflowai.co | React frontend — property listings dashboard |
| https://api.estateflowai.co/actuator/health | All services: db/mongo/rabbit/redis UP |
| https://api.estateflowai.co/api/users | Real user data from Aurora PostgreSQL |
| https://api.estateflowai.co/api/products | Property listings with Redis cache |
| https://api.estateflowai.co/api/orders | Orders with 4-DB write proof |
| https://grafana.estateflowai.co | Live metrics dashboards |
| https://argocd.estateflowai.co | GitOps — Synced + Healthy |

---

## Tech Stack

### AWS Managed Services
`EKS 1.32` `Aurora PostgreSQL 16.4` `ElastiCache Redis 8.6` `DocumentDB` `ALB` `ACM` `Route53` `ECR` `SSM Parameter Store` `SNS` `SQS` `Lambda` `CloudWatch` `EventBridge` `Security Hub` `GuardDuty` `Inspector v2` `CloudTrail` `AWS Config` `AWS Budgets` `Cost Anomaly Detection` `IAM IRSA` `KMS` `S3` `DynamoDB`

### Open Source Tools
`Kubernetes` `ArgoCD 2.9` `Karpenter 0.37` `Istio 1.20.3` `Prometheus` `Grafana` `OpenTelemetry` `External Secrets Operator` `AWS LBC` `Gitleaks` `Trivy` `Redis` `RabbitMQ 3.13` `Flyway` `Resilience4j` `Nginx` `k6`

### Application
`Spring Boot 3.2.3` `Java 17` `Maven` `React 18` `TypeScript` `Vite` `HikariCP` `Eclipse Temurin 17-jre-alpine`

### IaC + DevOps
`Terraform 1.7+` `AWS CDK Python` `GitHub Actions (OIDC)` `Python 3.12` `Boto3` `Kustomize`

---

## Repository Structure

```
compose-portal-application/
├── services/
│   ├── gateway-service/       # API gateway, rate limiting, circuit breaker
│   ├── user-service/          # Users, BCrypt, JWT, Aurora
│   ├── product-service/       # Properties, Redis cache
│   └── order-service/         # Orders, 4-DB writes, SNS
├── k8s/
│   ├── base/                  # Deployments, Services, HPA, PDB, ExternalSecrets
│   │   └── dr/                # DR runbook (RTO 30min, RPO 5min)
│   ├── overlays/dev/          # Kustomize image SHA overlays
│   ├── istio/                 # mTLS, DestinationRules, VirtualService canary
│   └── observability/         # OTel DaemonSet, scrape configs
├── infrastructure/terraform/
│   └── modules/
│       ├── vpc/               # VPC, subnets, NAT Gateways
│       ├── eks-cluster/       # EKS, OIDC, KMS, Karpenter
│       ├── eks-addons/        # ArgoCD, ESO, AWS LBC, Prometheus
│       ├── aurora-postgresql/ # Aurora 16.4, Multi-AZ, KMS
│       ├── elasticache-redis/ # Redis 8.6
│       ├── ecr/               # 5 repositories, lifecycle policies
│       ├── iam-roles/         # IRSA roles per service
│       └── alb/               # ALB, target groups
├── cdk/
│   ├── order_processing/      # SNS → SQS → Lambda (ComposePortalOrderProcessing)
│   └── aiops/
│       ├── lambda/triage_agent.py  # AIOps agent — 400 lines Python
│       ├── bedrock/agent-definition.json
│       └── eventbridge/alarm-rules.json
├── load-tests/                # k6 scenarios (smoke + load)
└── .github/workflows/ci-cd.yml  # 7-job pipeline
```

---

## CI/CD Pipeline

```
git push
  ↓
Job 1: detect-changes      path filters — only rebuild what changed
Job 2: gitleaks-scan       BLOCKS if any secret found
Job 3: maven-build         compile + JUnit tests (H2 in-memory)
Job 4: docker-build        multi-stage: JDK builder → JRE runtime
                           --provenance=false (prevents ECR pull issues)
Job 5: trivy-scan          BLOCKS on CRITICAL CVEs
Job 6: ecr-push            OIDC auth — no stored AWS keys
                           tagged with git SHA (traceable)
Job 7: gitops-update       kustomization.yaml SHA updated → git push
  ↓
ArgoCD detects change → applies rolling update → Synced + Healthy
  ↓
Pod running in production
```

Zero manual steps. Zero stored credentials. Every pod traceable to exact git commit.

---

## Security Architecture

```
Layer 1: Pre-commit
  Gitleaks → blocks secrets before remote push

Layer 2: CI pipeline
  Trivy → blocks CRITICAL CVEs before ECR
  OIDC → no stored AWS credentials anywhere

Layer 3: Kubernetes runtime
  IRSA → per-pod 1-hour TTL credentials
  ExternalSecrets → SSM → K8s Secrets (never in Git)
  PodSecurity → enforce=restricted
  Istio → mTLS + AuthorizationPolicy

Layer 4: AWS account
  Security Hub → FSBP + CIS 1.4.0
  GuardDuty → ML threat detection (0 threats)
  Inspector v2 → CVE scan on every push
  CloudTrail → every API call, 7 years
  AWS Config → every resource change recorded

Layer 5: AIOps
  CloudWatch → EventBridge → Lambda
  208ms RCA → structured JSON output
  MTTR: 47 min → 3 min
```

---

## Key Engineering Decisions

| Decision | Chosen | Why Not Alternative |
|----------|--------|-------------------|
| GitOps | ArgoCD | FluxCD: weaker UI + observability |
| Node autoscaling | Karpenter | Cluster Autoscaler: 3-5 min vs 60-90s |
| Secret sync | External Secrets Operator | Sealed Secrets: no centralised rotation |
| Service mesh | Istio PERMISSIVE | STRICT blocked by PodSecurity (NET_ADMIN) |
| CI auth | OIDC | Stored keys: never expire, leak risk |
| Image tags | git SHA | `:latest` is mutable — untraceable |
| Databases | Aurora per service | Shared DB: one slow query blocks all |
| Cache | Redis ElastiCache | Memcached: no persistence or cluster mode |

---

## Production Bugs Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | CrashLoopBackOff | K8s injects `USER_SERVICE_PORT=tcp://...` → Spring `parseInt` fails | Explicit `SERVER_PORT=808X` in every Deployment |
| 2 | order-service 503 | `RABBITMQ_HOST` in SSM but absent from ExternalSecret | Add key to ExternalSecret YAML → commit → ArgoCD sync |
| 3 | Gateway UNKNOWN health | Spring Cloud Discovery Client enabled | `spring.cloud.discovery.enabled: false` in k8s profile |
| 4 | YAML crash | `cat >>` appended second `spring:` root key | Python replace fix inside existing spring block |
| 5 | ECR push fails | Immutable tag cannot be overwritten | Delete digest first → then push |
| 6 | EKS ImagePullBackOff | `docker buildx` attestation manifests incompatible with ECR | Always use `--provenance=false` |
| 7 | Karpenter nodes not joining | Karpenter node role missing from `aws-auth` | Add role to aws-auth ConfigMap |
| 8 | ArgoCD reverts image | `kubectl set image` causes drift → ArgoCD reverts | Update `kustomization.yaml` in Git only |
| 9 | Circuit breaker stuck OPEN | Stale Resilience4j in-memory state | `kubectl rollout restart gateway-service` |
| 10 | All pods blocked by Istio | Init container needs `NET_ADMIN` blocked by PodSecurity | Use `PERMISSIVE` not `STRICT` mTLS |
| 11 | DocumentDB TLS failure | MongoDB driver 4.x ignores `tlsCAFile` URI param | Import AWS CA into JVM `cacerts` via `keytool` in Dockerfile |
| 12 | Maven CI failure | Parent POM not found from service subdirectory | `mvn install -N -q` from repo root first |
| 13 | Lambda syntax error | Multi-line f-strings not allowed in Python | Regex joined broken f-strings to single line |

---

## Roadmap

- [x] EKS + Aurora + Redis + External Secrets + HPA + Karpenter
- [x] GitHub Actions 7-job CI/CD (OIDC, Gitleaks, Trivy)
- [x] ArgoCD GitOps (selfHeal, drift detection)
- [x] Istio Service Mesh (mTLS, canary, AuthorizationPolicy)
- [x] OTel + Prometheus + Grafana observability stack
- [x] AIOps Lambda (CloudWatch → EventBridge → RCA → 208ms)
- [x] FinOps (Budgets + Cost Anomaly Detection + Karpenter Spot)
- [x] DR (ECR replication + Route53 health check)
- [x] DevSecOps (Security Hub + GuardDuty + Inspector + CloudTrail + Config)
- [ ] AI Agent Platform (10 autonomous agents on AWS Bedrock)
- [ ] Backstage IDP (self-service developer portal)

---

## Author

**Nimmala Balakrishna** — Senior AWS DevOps Engineer | ~8 years experience

[![LinkedIn](https://img.shields.io/badge/LinkedIn-nimmala--balakrishna-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/nimmala-balakrishna/)
[![Email](https://img.shields.io/badge/Email-nbalakrishna.devops%40gmail.com-red?style=flat&logo=gmail)](mailto:nbalakrishna.devops@gmail.com)

AWS SAA-C03 Certified | Kubernetes | Terraform | Hyderabad, India

---

*AWS ap-south-1 | EKS 1.32 | Terraform 97 resources | Spring Boot 3.2.3 | Jan 2025 – Jan 2026*
