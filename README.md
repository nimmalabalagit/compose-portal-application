# EstateFlow AI — Cloud-Native Real Estate Platform

Production-grade microservices platform on AWS EKS 1.32 with GitOps, observability, and enterprise security.

## Live Platform

| URL | Description |
|-----|-------------|
| https://www.estateflowai.co | React 18 Command Center UI |
| https://api.estateflowai.co/actuator/health | Gateway API Health |
| https://grafana.estateflowai.co | Grafana (admin/admin123) |
| https://argocd.estateflowai.co | ArgoCD (admin/M-KJGnatepaF3PfS) |

## Services

| Service | Port | Database | Purpose |
|---------|------|----------|---------|
| gateway-service | 8080 | Redis | Routing, circuit breaker, rate limiting |
| user-service | 8081 | Aurora users_db + Redis | User management, BCrypt auth |
| product-service | 8082 | Aurora products_db + Redis | Real estate listings |
| order-service | 8083 | Aurora orders_db + DocumentDB + RabbitMQ | Order processing + audit |
| frontend | 80 | nginx | React 18 dark command center UI |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Cloud | AWS EKS 1.32, Aurora PostgreSQL 16.4, ECR, ACM, Route53 |
| IaC | Terraform, AWS CDK v2 Python |
| CI/CD | GitHub Actions + ArgoCD GitOps |
| Security Gates | Gitleaks, Checkov, Trivy, OPA/Conftest |
| Secrets | External Secrets Operator + AWS Parameter Store |
| Autoscaling | Karpenter v0.37 Spot + HPA |
| Observability | Prometheus + Grafana + OpenTelemetry + Loki + Tempo |
| Security | Security Hub FSBP + CIS 1.4 + GuardDuty + Inspector v2 + CloudTrail |
| App Stack | Spring Boot 3.2.3 / Java 17 + React 18 / TypeScript |
| Databases | Aurora PostgreSQL + Redis 8.6 + DocumentDB + RabbitMQ |

## Key Production Bugs Fixed

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| CrashLoopBackOff on scale-up | K8s injects RABBITMQ_PORT=tcp://... overriding Spring | Explicit RABBITMQ_PORT=5672 in all manifests |
| DocumentDB TLS failure | MongoDB Java driver ignores tlsCAFile URI param | Import RDS CA bundle into JVM cacerts in Dockerfile |
| ECR push failure | Immutable tag already exists | Delete image digest before re-push |
| esbuild EACCES in Docker | WSL node_modules permissions corrupt on Alpine | Add node_modules to .dockerignore |
| Frontend calling localhost | .env excluded from Docker build | Remove .env from .dockerignore, keep .env.local excluded |
| ArgoCD kustomize error | echo appended two resources on one line | python3 replace to fix kustomization.yaml |

## Security

| Tool | Purpose | Status |
|------|---------|--------|
| Security Hub FSBP | Cloud security posture | Active |
| Security Hub CIS 1.4 | Compliance benchmark | Active |
| GuardDuty | ML threat detection | Active |
| Inspector v2 | EC2 + ECR CVE scanning | Active |
| CloudTrail | Multi-region audit logging | Active |
| IRSA | Pod-level AWS identity | Active |
| External Secrets | Zero secrets in Git | Active |
| Trivy | Container CVE gate in CI | Active |
| Gitleaks | Secret scanning pre-commit | Active |

## Author

**Nimmala Balakrishna** — Distinguished AWS DevOps Engineer

nbalakrishna.devops@gmail.com | +91-9652567807 | https://linkedin.com/in/nimmala-balakrishna

AWS SAA-C03 | Terraform Associate | Kubernetes (CKA in pursuit)
