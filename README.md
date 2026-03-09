# charis-repo

Multi-environment delivery pipeline for `charis-api` — a minimal containerised Go API used to demonstrate a production-grade DevOps setup.

**Stack:** Go · Docker · Terraform ≥ 1.6 · GitHub Actions · Azure Pipelines  
**Environments:** Staging → Azure (West Europe) · Production → AWS (us-east-1)

---

## Live Endpoints (AWS Production)

| Resource | URL |
|---|---|
| Health check (CloudFront) | `https://d2myxx207nvjw6.cloudfront.net/healthz` |
| CloudFront domain | `https://d2myxx207nvjw6.cloudfront.net` |
| CloudFront distribution ID | `E1VANYCFL5SG` |
| ECR registry | `272558305119.dkr.ecr.us-east-1.amazonaws.com/charis-api` |
| ALB direct | `charis-api-alb-188676199.us-east-1.elb.amazonaws.com:8080` |

---

## Architecture Overview

```text
GitHub Actions CI
  ├── Build multi-stage Docker image (Go + scratch base, ~6 MB)
  ├── Push to AWS ECR (sha tag + semver tag if present)
  ├── Trivy vulnerability scan (blocks on CRITICAL/HIGH)
  ├── SBOM generation (Syft → spdx-json)
  └── Terraform plan for both environments

Azure Pipelines (deploy, gated)
  ├── [Manual approval] Deploy to Azure Staging
  │     Web App for Containers (B1) + Azure CDN
  │     Health gate: /healthz must return 200 within 2 min
  ├── [Manual approval] Deploy to AWS Production
  │     ECS Fargate (70% Spot / 30% On-demand) + ALB + CloudFront + WAF
  │     Health gate + ECS circuit breaker auto-rollback
  └── CloudFront cache invalidation

## What I Did Beyond the Basic Requirements

The assessment asked for a working pipeline. I treated it as a production system and added
the following on top of the minimum requirements:

### Security Improvements

| Improvement | Detail |
|---|---|
| Zero stored credentials | AWS uses GitHub OIDC federation. Azure uses Workload Identity Federation. No access keys or JSON secrets stored anywhere |
| WAF with rate limiting | Added rate-based rule (1000 req / 5 min per IP) on top of OWASP Core Rule Set and Known Bad Inputs — protects against DDoS and brute force |
| Scratch Docker base image | Final image has zero OS packages, no shell, runs as UID 65534 (non-root), read-only root filesystem — minimal attack surface |
| Security headers at CDN | HSTS, X-Frame-Options, X-Content-Type-Options, XSS-Protection enforced at CloudFront edge before traffic reaches the origin |
| X-Origin-Verify header | CloudFront adds a shared secret header to every origin request — prevents direct ALB access that would bypass WAF |
| Immutable ECR image tags | Once pushed, an image tag cannot be overwritten — eliminates silent supply chain tampering |
| Trivy scan gate | Pipeline blocks on unfixed CRITICAL/HIGH CVEs — no vulnerable image can reach production |
| SBOM generation | Syft generates a full Software Bill of Materials (spdx-json) on every build for supply chain transparency |

### Cost Optimisation

| Optimisation | Saving |
|---|---|
| ECS Fargate Spot (70%) | Spot capacity for non-critical tasks reduces compute cost by ~60-70% vs On-Demand |
| CloudFront PriceClass_100 | Restricts CDN to North America + Europe edge nodes only — eliminates expensive Asia-Pacific and South America pricing |
| S3 Intelligent-Tiering | Static assets automatically move to cheaper storage tiers after 30 days of inactivity |
| CloudWatch Budget alarm | Hard alert at 80% of $10/day budget — prevents runaway spend going unnoticed |
| `pause_deploy` variable | Halts new deployments without destroying infrastructure — avoids full rebuild cost during maintenance windows |
| 30-day log retention | CloudWatch log groups capped at 30 days — prevents unbounded log storage cost |
| NAT Gateway trade-off | Documented: VPC Endpoints for ECR/S3 would eliminate NAT Gateway cost (~$32/month) at the expense of setup complexity |

### Operational Improvements

| Improvement | Detail |
|---|---|
| SLO alarms | CloudWatch alarms for 5xx error rate > 2% and P95 latency > 300ms |
| ECS deployment circuit breaker | Auto-rollback on failed deployment — no manual intervention needed |
| Graceful shutdown | Go API handles SIGTERM cleanly — zero dropped requests during rolling updates |
| State locking | DynamoDB prevents concurrent Terraform applies corrupting remote state |
| Environment isolation | `prod-aws` and `staging-azure` are fully separate Terraform roots — a mistake in staging cannot affect production |
