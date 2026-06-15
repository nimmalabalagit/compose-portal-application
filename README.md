# EstateFlow AI — Cloud-Native Microservices Platform
## Production-Grade AWS DevOps Portfolio | EKS 1.32 | GitOps | AIOps | Istio | Terraform

<div align="center">

![Platform Status](https://img.shields.io/badge/Platform-Live-brightgreen?style=for-the-badge&logo=amazonaws)
![EKS Version](https://img.shields.io/badge/EKS-v1.32-orange?style=for-the-badge&logo=kubernetes)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.2.3-green?style=for-the-badge&logo=springboot)
![Terraform](https://img.shields.io/badge/Terraform-97_Resources-purple?style=for-the-badge&logo=terraform)
![ArgoCD](https://img.shields.io/badge/ArgoCD-Synced_%26_Healthy-blue?style=for-the-badge&logo=argo)
![Bedrock](https://img.shields.io/badge/Amazon_Bedrock-10_Agents-FF9900?style=for-the-badge&logo=amazonaws)

**Live:** [estateflowai.co](https://www.estateflowai.co) | **API:** [api.estateflowai.co/actuator/health](https://api.estateflowai.co/actuator/health) | **Grafana:** [grafana.estateflowai.co](https://grafana.estateflowai.co)

</div>

---

## What This Is

EstateFlow AI is a **production-grade, cloud-native microservices platform** built to demonstrate Principal-level AWS DevOps engineering. It runs 4 Spring Boot 3.2.3 microservices on Amazon EKS 1.32 in ap-south-1 — fully automated via GitOps, secured with defence-in-depth, and operated by 10 autonomous AIOps agents powered by Amazon Bedrock.

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
AIOPS:          CloudWatch Alarm → EventBridge → 10 Bedrock Agents (MTTR 3 min)
GITOPS:         GitHub Actions 7 jobs → ArgoCD selfHeal → EKS rolling update
IAC:            Terraform 97 resources (8 modules) + AWS CDK Python
DR:             ECR cross-region replication + Route53 health check auto-failover
FINOPS:         AWS Budgets + Cost Anomaly Detection + Karpenter Spot (70% saving)
```

---

## Platform Metrics

| Metric | Value |
|--------|-------|
| Pipeline: git push → pod running | **8 minutes** |
| Load test RPS | **26.4 RPS** |
| Load test P95 latency | **163ms** |
| Error rate | **0.33%** |
| MTTR (10 AIOps Bedrock agents) | **3 minutes** (was 47 min) |
| Terraform resources | **97 live** |
| Compute cost saving | **70%** (Karpenter Spot) |
| Cost per 1,000 requests | **$0.0051** |
| Daily platform cost | **$11.69** |
| SSM parameters | **21** |
| AIOps agents | **10 autonomous** |
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
`EKS 1.32` `Aurora PostgreSQL 16.4` `ElastiCache Redis 8.6` `DocumentDB` `ALB` `ACM` `Route53` `ECR` `SSM Parameter Store` `SNS` `SQS` `Lambda` `CloudWatch` `EventBridge` `Security Hub` `GuardDuty` `Inspector v2` `CloudTrail` `AWS Config` `AWS Budgets` `Cost Anomaly Detection` `IAM IRSA` `KMS` `S3` `DynamoDB` `Amazon Bedrock`

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
│   ├── overlays/dev/          # Kustomize image SHA overlays
│   ├── istio/                 # mTLS, DestinationRules, VirtualService canary
│   └── observability/         # OTel DaemonSet, scrape configs
├── infrastructure/terraform/
│   └── modules/               # vpc, eks-cluster, eks-addons, aurora, redis, ecr, iam-roles, alb
├── agents/                    # 10 autonomous AIOps agents (NEW)
│   └── lambda/
│       ├── agent1_incident/        # CloudWatch alarm → RCA + auto-rollback P3/P4
│       ├── agent2_security/        # Security Hub finding → Terraform fix PR
│       ├── agent3_finops/          # Daily cost report → Slack
│       ├── agent4_pipeline/        # CI failure → PR comment with root cause
│       ├── agent5_pr_reviewer/     # PR opened → security + reliability review
│       ├── agent6_postmortem/      # Incident resolved → blameless RCA to S3
│       ├── agent7_capacity/        # Weekly HPA trend analysis → GitHub issue
│       ├── agent8_knowledge/       # New incident pattern → runbook update
│       ├── agent9_compliance/      # Weekly SOC2 evidence bundle → S3
│       ├── agent10_deploy_decision/ # GO/NO-GO gate before every ArgoCD sync
│       └── common_layer/           # Shared Bedrock client + SNS notifications
├── cdk/
│   ├── app.py                 # CDK entry point
│   ├── agent_platform_stack.py # Deploys all 10 agents (~$0.86/day) (NEW)
│   ├── lambda/order-processor/ # SNS → SQS → Lambda order processing
│   └── aiops/                 # Phase E triage agent + EventBridge rules
├── backstage/                 # Internal Developer Portal
│   ├── app-config.yaml
│   ├── catalog-info.yaml
│   ├── catalog/               # API, components, resources, system
│   └── templates/             # Golden-path microservice template
├── organizations/             # AWS Organizations multi-account governance (NEW)
│   └── main.tf                # 4 OUs + 5 SCPs + tag policies
├── load-tests/                # k6 smoke + load scenarios
└── .github/workflows/ci-cd.yml  # 7-job pipeline
```

---

## AIOps Agent Platform (Phase F)

10 autonomous Lambda functions powered by Amazon Bedrock (Claude 3.5 Sonnet + Haiku).

| Agent | Trigger | Action |
|-------|---------|--------|
| **1. Incident Responder** | CloudWatch Alarm | RCA + auto-rollback for P3/P4 incidents |
| **2. Security Remediator** | Security Hub finding | Terraform fix → GitHub issue |
| **3. FinOps Optimizer** | Daily cron 6 AM IST | 7-day cost analysis → GitHub issue |
| **4. Pipeline Doctor** | GitHub Actions failure | Root cause → commit comment |
| **5. PR Reviewer** | PR opened/updated | Security + reliability review → PR comment |
| **6. Post-Mortem Writer** | Incident resolved | Blameless RCA → S3 + GitHub issue |
| **7. Capacity Planner** | Weekly cron Monday | HPA trend analysis → GitHub issue |
| **8. Knowledge Manager** | Post-incident SNS | Runbook update → GitHub commit |
| **9. Compliance Agent** | Weekly cron Sunday | SOC2 evidence bundle → S3 |
| **10. Deploy Decision** | Pre-deploy API call | GO/NO-GO based on alarms + CVEs + error rates |

> **AWS validation:** AWS launched DevOps Agent (GA March 2026), Security Agent (GA March 2026), and FinOps Agent (Preview June 2026) — covering Agents 1, 2, 3. Agents 8, 9, 10 have no AWS managed equivalent. This platform predates all three AWS managed services by 12+ months.

---

## CI/CD Pipeline

```
git push
  ↓
Job 1: detect-changes      path filters — only rebuild what changed
Job 2: gitleaks-scan       BLOCKS if any secret found
Job 3: maven-build         compile + JUnit tests (H2 in-memory)
Job 4: docker-build        multi-stage: JDK builder → JRE runtime (--provenance=false)
Job 5: trivy-scan          BLOCKS on CRITICAL CVEs
Job 6: ecr-push            OIDC auth — no stored AWS keys, git SHA tag
Job 7: gitops-update       kustomization.yaml SHA updated → ArgoCD auto-sync
  ↓
Pod running in production — zero manual steps, zero stored credentials
```

---

## Security Architecture

```
Layer 1: Pre-commit    → Gitleaks blocks secrets before push
Layer 2: CI pipeline   → Trivy blocks CRITICAL CVEs, OIDC (no stored keys)
Layer 3: K8s runtime   → IRSA (1hr TTL), ExternalSecrets (SSM→K8s), Istio mTLS
Layer 4: AWS account   → Security Hub FSBP+CIS, GuardDuty, Inspector v2, CloudTrail
Layer 5: AIOps         → Bedrock agents triage and remediate in under 3 minutes
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
| AIOps | Custom Bedrock agents | Built 6 months before AWS shipped managed equivalents |

---

## Production Bugs Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | CrashLoopBackOff | K8s injects `USER_SERVICE_PORT=tcp://...` → Spring `parseInt` fails | Explicit `SERVER_PORT=808X` in every Deployment |
| 2 | order-service 503 | `RABBITMQ_HOST` absent from ExternalSecret | Add key to ExternalSecret YAML |
| 3 | Gateway UNKNOWN health | Spring Cloud Discovery Client enabled | `spring.cloud.discovery.enabled: false` |
| 4 | YAML crash | Second `spring:` root key appended | Python replace fix |
| 5 | ECR push fails | Immutable tag cannot be overwritten | Delete digest first |
| 6 | EKS ImagePullBackOff | Docker buildx attestation manifests | Always use `--provenance=false` |
| 7 | Karpenter nodes not joining | Node role missing from `aws-auth` | Add role to aws-auth ConfigMap |
| 8 | ArgoCD reverts image | `kubectl set image` causes drift | Update `kustomization.yaml` in Git only |
| 9 | Circuit breaker stuck OPEN | Stale Resilience4j state | `kubectl rollout restart gateway-service` |
| 10 | Istio blocks pods | NET_ADMIN blocked by PodSecurity | Use PERMISSIVE not STRICT mTLS |
| 11 | DocumentDB TLS failure | MongoDB driver ignores `tlsCAFile` | Import AWS CA into JVM cacerts in Dockerfile |
| 12 | Maven CI failure | Parent POM not found from service dir | `mvn install -N -q` from repo root first |
| 13 | Lambda syntax error | Multi-line f-strings not allowed | Regex joined broken f-strings |

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
- [x] AI Agent Platform (10 autonomous Bedrock agents — Agents 8/9/10 have no AWS equivalent)
- [x] Backstage IDP (self-service developer portal)
- [x] AWS Organizations (4 OUs, 5 SCPs, tag policies)

---

## Author

**Nimmala Balakrishna** — Senior AWS DevOps Engineer | ~8 years experience

[![LinkedIn](https://img.shields.io/badge/LinkedIn-nimmala--balakrishna-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/nimmala-balakrishna/)
[![Email](https://img.shields.io/badge/Email-nbalakrishna.devops%40gmail.com-red?style=flat&logo=gmail)](mailto:nbalakrishna.devops@gmail.com)

AWS | Kubernetes | Terraform | Hyderabad, India

---
*AWS ap-south-1 | EKS 1.32 | Terraform 97 resources | Spring Boot 3.2.3 | 2026*
