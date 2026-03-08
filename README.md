# charis-repo

Multi-environment delivery pipeline for `charis-api` — a minimal containerised Go API used to demonstrate a production-grade DevOps setup.

**Stack:** Go · Docker · Terraform ≥ 1.6 · GitHub Actions · Azure Pipelines  
**Environments:** Staging → Azure (West Europe) · Production → AWS (us-east-1)

---

## Architecture Overview

```
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
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.6 |
| Docker | any recent |
| AWS CLI | v2 |
| Azure CLI | latest |
| Go | 1.22 (local dev only) |

---

## Quick Start — Local Development

```bash
# 1. Build and run the API locally
cd app
docker build -t charis-api:local .
docker run --rm -p 8080:8080 charis-api:local

# 2. Verify health endpoint
curl http://localhost:8080/healthz
# {"status":"ok","version":"dev","timestamp":"2026-03-05T10:00:00Z"}
```

---

## Bootstrap — Remote State (run once)

Before the first `terraform init`, create the state backends.

### AWS — S3 + DynamoDB

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket charis-tf-state-prod \
  --region us-east-1

# Enable versioning (protects against accidental state loss)
aws s3api put-bucket-versioning \
  --bucket charis-tf-state-prod \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket charis-tf-state-prod \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name charis-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Azure — Storage Account

```bash
# Create resource group for state
az group create --name charis-tf-state-rg --location westeurope

# Create storage account (name must be globally unique, lowercase, max 24 chars)
az storage account create \
  --name charistfstate \
  --resource-group charis-tf-state-rg \
  --location westeurope \
  --sku Standard_LRS \
  --min-tls-version TLS1_2

# Create blob container
az storage container create \
  --name tfstate \
  --account-name charistfstate
```

---

## Terraform — AWS Production

```bash
cd infra/envs/prod-aws

# Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set github_org, budget_alert_emails, etc.

# Initialise with remote state
terraform init

# Preview changes (no cost incurred)
terraform plan -var="image_tag=sha-abc1234"

# Apply (creates all AWS infrastructure)
terraform apply -var="image_tag=sha-abc1234"

# Get outputs (ECR URL, CloudFront domain, deploy role ARN)
terraform output
```

**After first apply**, copy the `github_deploy_role_arn` output and save it as a GitHub Actions secret:

```bash
# In your GitHub repo → Settings → Secrets → New secret
# Name:  AWS_DEPLOY_ROLE_ARN
# Value: arn:aws:iam::123456789:role/charis-api-github-deploy
```

---

## Terraform — Azure Staging

```bash
cd infra/envs/staging-azure

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

# Get ECR password (needed for Azure to pull from ECR)
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

terraform init
terraform plan -var="image_tag=sha-abc1234" -var="ecr_password=$ECR_PASSWORD"
terraform apply -var="image_tag=sha-abc1234" -var="ecr_password=$ECR_PASSWORD"

terraform output
```

---

## CI/CD Flow

### GitHub Actions (`.github/workflows/ci.yml`)

Every push to `main`:
1. Builds the Docker image with BuildKit layer cache
2. Trivy scan — blocks on unfixed CRITICAL/HIGH CVEs
3. Generates SBOM (spdx-json)
4. Pushes image to ECR with `sha-<short-sha>` tag (and semver tag if a git tag exists)
5. Runs `terraform plan` for both environments and uploads plan artifacts

Pull requests trigger build + scan only — no push, no plan.

### Azure Pipelines (`azure-pipelines.yml`)

Triggered manually with an image tag parameter:
1. **Staging deploy** — `terraform apply` → health gate (2 min) → manual approval
2. **Prod deploy** — `terraform apply` → health gate (3 min) → CloudFront cache invalidation
3. **Auto-rollback** — ECS deployment circuit breaker reverts to previous stable task definition

### How CI artifacts flow into deploy

```
GitHub Actions           Azure Pipelines
─────────────────────    ──────────────────────────────────────────
1. Build image           4. Triggered with imageTag=sha-abc1234
2. Push sha-abc1234  →   5. terraform apply -var image_tag=sha-abc1234
3. Upload tfplan      →   6. Download tfplan artifact, apply pre-approved plan
```

---

## Rollback

### One-command rollback — Staging (Azure)

```bash
# Re-run the pipeline with the previous image tag
az webapp config container set \
  --name charis-api-staging \
  --resource-group charis-api-staging-rg \
  --docker-custom-image-name <ECR_REGISTRY>/charis-api:<last-good-tag>
```

### One-command rollback — Production (AWS)

```bash
# ECS circuit breaker handles this automatically.
# For manual override:
aws ecs update-service \
  --cluster charis-api \
  --service charis-api \
  --task-definition <previous-task-def-arn> \
  --force-new-deployment
```

---

## GitHub Secrets Required

| Secret | Where to get it |
|--------|----------------|
| `AWS_DEPLOY_ROLE_ARN` | `terraform output github_deploy_role_arn` in prod-aws |
| `AZURE_CREDENTIALS` | `az ad sp create-for-rbac --sdk-auth` |
| `ECR_PASSWORD` | `aws ecr get-login-password --region us-east-1` (refresh periodically) |

## Azure DevOps Variables (Library Group: `charis-deploy-secrets`)

| Variable | Description |
|----------|-------------|
| `AZURE_SERVICE_CONNECTION` | Azure service connection name |
| `AWS_SERVICE_CONNECTION` | AWS service connection name |
| `AZURE_WEBAPP_NAME` | `charis-api-staging` |
| `ECR_REGISTRY` | `<account>.dkr.ecr.us-east-1.amazonaws.com` |
| `ECR_PASSWORD` | ECR auth token |
| `CLOUDFRONT_DOMAIN` | CloudFront domain from prod-aws outputs |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID |
| `TF_STATE_RG` | `charis-tf-state-rg` |
| `TF_STATE_SA` | `charistfstate` |
| `GITHUB_ORG` | Your GitHub username |

---

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| ECS Fargate Spot (256 CPU / 512 MB × 2 tasks) | ~$3–5 |
| ALB | ~$16 |
| CloudFront (PriceClass_100, low traffic) | ~$1 |
| ECR (< 500 MB storage) | < $1 |
| CloudWatch Logs (30-day retention) | ~$1 |
| Azure Web App B1 | ~$13 |
| Azure CDN (low traffic) | ~$1 |
| **Total** | **~$35–40/month** |

See `COST_NOTES.md` for trade-off analysis and optimisation options.

## Operational Improvements

The infrastructure configuration includes several operational safeguards and best practices:

- **Deployment Safety Switch** – `pause_deploy` allows temporarily disabling WebApp deployment without removing configuration.
- **Application Monitoring** – Azure Application Insights is configured for telemetry and diagnostics.
- **Health Checks** – The WebApp uses `/healthz` endpoint for automatic instance recovery.
- **Terraform Module Structure** – Infrastructure components are modularized for reuse and maintainability.
- **Environment Separation** – Environment specific configurations are isolated under `infra/envs/`.

These improvements increase reliability, maintainability, and operational safety of the deployment.
