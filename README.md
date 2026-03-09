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

