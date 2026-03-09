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
