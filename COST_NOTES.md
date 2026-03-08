# Cost & Performance Notes

This document describes cost trade-offs and default performance configurations.

---

# Load Balancer Architecture Comparison

## ALB

Pros

• native support for ECS and container workloads  
• layer 7 routing  
• integrated health checks  
• supports WAF  

Cons

• fixed hourly cost even with low traffic

Best suited for:

container workloads with dynamic scaling.

---

## API Gateway

Pros

• serverless  
• no infrastructure to manage  
• strong throttling controls  

Cons

• higher cost per request at scale  
• less suitable for long-lived connections

Best suited for:

low traffic APIs or event-driven architectures.

---

## CloudFront Only

Pros

• very low latency globally  
• integrated caching  
• cost-efficient for static assets  

Cons

• cannot replace an application load balancer for dynamic workloads.

Best suited for:

static websites and CDN acceleration.

---

# Selected Architecture

This project uses:

CloudFront → ALB → ECS Fargate

Reasoning:

• CloudFront provides global edge caching  
• ALB manages container traffic and health checks  
• ECS provides container orchestration.

This balances cost and operational simplicity.

---

# Autoscaling Policy

ECS service autoscaling configuration:

Minimum tasks

2

Maximum tasks

6

Scaling metric

CPU utilization.

Scaling rules:

Scale out when:

CPU > 60% for 2 minutes

Scale in when:

CPU < 30% for 10 minutes

This configuration prevents rapid scaling oscillations.

---

# Static Asset Caching

CloudFront caching policy:

TTL:

---

## ALB vs API Gateway vs CloudFront-only — Trade-off Analysis

This service currently uses **ALB + CloudFront** for the API and **CloudFront + S3** for static assets. Here is the full comparison for a small, low-traffic service.

| | ALB + CloudFront | API Gateway (HTTP API) + CloudFront | CloudFront-only (Lambda@Edge) |
|---|---|---|---|
| **Monthly base cost** | ~$16 (ALB) + ~$1 (CF) | ~$1–3 (per-request) + ~$1 (CF) | ~$1 (CF) + Lambda@Edge cost |
| **Break-even** | >10M req/month | <10M req/month | Any traffic |
| **Cold start** | None | None | ~1–5ms (Lambda@Edge) |
| **Container support** | Native | Via VPC Link + NLB | No — Lambda only |
| **WebSocket / streaming** | Yes | Yes | No |
| **Max request size** | Unlimited | 10 MB | 1 MB |
| **Custom auth** | Via Lambda authorizer | Built-in JWT/IAM | Custom Lambda |
| **Ops complexity** | Low | Medium | High |
| **Verdict for this service** | ✓ Chosen — simple, predictable cost at low traffic | Better at very low traffic (<100K req/day) if container → Lambda migration is acceptable | Not viable — service is containerised |

**Decision rationale:** ALB was chosen because:
1. ECS Fargate requires a stable load balancer as origin — CloudFront cannot point to dynamic task IPs
2. ALB cost (~$16/month) is fixed and predictable; API Gateway + VPC Link would add an NLB (~$16) and usage fees
3. Fargate Spot reduces compute cost by ~70%, offsetting the ALB fixed cost

**Optimisation path:** At <100K requests/day, replacing the container with a Lambda function and using API Gateway HTTP API would reduce total API infrastructure cost from ~$17 to ~$2/month. Document this in a future spike if traffic remains low.

---

## Default Autoscaling Policy

### ECS Fargate (Production)

```hcl
# Target: 70% average CPU across all tasks
# Scale-out: add tasks within 60 seconds of threshold breach
# Scale-in: remove tasks after 300 seconds below threshold (prevents thrashing)
target_tracking_scaling_policy_configuration {
  predefined_metric_type = "ECSServiceAverageCPUUtilization"
  target_value           = 70.0
  scale_out_cooldown     = 60
  scale_in_cooldown      = 300
}
min_capacity = 1
max_capacity = 10
```

**Fargate Spot mix:** 70% Spot / 30% On-demand. On-demand base of 1 ensures at least one always-available task during Spot interruptions. At 256 CPU / 512 MB, Spot saves ~$0.007/hour vs on-demand.

### Azure Web App (Staging)

B1 plan does not support autoscaling. If staging receives load tests, temporarily upgrade to P1v3 and enable:

```bash
az monitor autoscale create \
  --resource-group charis-api-staging-rg \
  --resource charis-api-staging \
  --resource-type Microsoft.Web/serverFarms \
  --min-count 1 --max-count 3 --count 1

az monitor autoscale rule create \
  --autoscale-name charis-api-staging \
  --condition "CpuPercentage > 70 avg 5m" \
  --scale out 1
```

---

## Static Asset Caching Strategy

| Asset Type | Cache-Control | CloudFront TTL | Rationale |
|------------|--------------|----------------|-----------|
| `*.html` | `no-cache` | 5 minutes | Must reflect latest deploy |
| `*.js`, `*.css` (hashed names) | `max-age=31536000, immutable` | 1 year | Content-hashed filenames change on rebuild |
| `*.png`, `*.svg`, images | `max-age=604800` | 7 days | Rarely changes |
| `/healthz` | `no-cache` | Bypass (CachingDisabled policy) | Health checks must reach origin |
| `/api/*` | `no-store` | Bypass (CachingDisabled policy) | API responses are dynamic |

CloudFront compression (`compress = true`) is enabled — gzip/brotli applied automatically at edge.

---

## Daily Budget Guardrail

A CloudWatch Budgets alert fires at 80% of the $10/day threshold:

```hcl
resource "aws_budgets_budget" "daily" {
  name         = "charis-api-daily-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["your@email.com"]
  }
}
```

### Pipeline Toggle — Pause Prod Deploys

The `pause_deploy` variable in both environment configurations acts as an emergency switch. When set to `true` in the CI environment, the pipeline skips the apply step:

```bash
# In GitHub Actions — set environment variable or repo variable
TF_VAR_pause_deploy=true

# In Azure Pipelines — set pipeline variable
pause_deploy=true
```

In Terraform, resources that cost money when idle (e.g. ALB, NAT Gateway) can optionally be wrapped in a `count = var.pause_deploy ? 0 : 1` block to fully tear down and stop billing.

---

## Two Near-Term Cost Optimisations

### 1. Replace NAT Gateway with VPC Endpoints (~$30/month saving)

The current architecture routes ECR image pulls from ECS tasks through a NAT Gateway (~$32/month including data processing). ECR, CloudWatch Logs, and S3 all support VPC Interface Endpoints, which route traffic within the AWS network and eliminate NAT Gateway data charges.

```hcl
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = module.ecs.vpc_id
  service_name      = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.ecs.private_subnet_ids
}
```

**Trade-off:** Each Interface Endpoint costs ~$7.30/month. Two endpoints (ECR + CloudWatch) = ~$15/month, saving ~$17/month net vs NAT Gateway for this workload.

### 2. Switch to ECS Fargate Spot 100% for Staging

Staging is already on B1 (Azure, ~$13/month). If the AWS side of staging were used, switching to 100% Fargate Spot would save ~70% on compute. For the production mix, increasing Spot weight from 70% to 90% is safe if the service can tolerate a <2-minute interruption window handled by ECS circuit breaker.

```hcl
# Change in ecs-fargate module for staging
default_capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 100
  base              = 0
}
```

