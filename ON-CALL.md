# On-Call Runbook

Covers: first-15-minutes response, comms template, rollback steps, and postmortem template.

---

## First 15 Minutes — Incident Checklist

### Minute 0–2: Confirm the incident

```bash
# Is the public endpoint up?
curl -I https://<cloudfront-domain>/healthz

# Is staging up?
curl -I https://charis-api-staging.azurewebsites.net/healthz
```

- [ ] Check the CloudWatch SLO burn alarm in AWS Console → CloudWatch → Alarms
- [ ] Check Azure Monitor → Alerts
- [ ] Confirm whether it is prod-only, staging-only, or both

### Minute 2–5: Identify impact scope

- [ ] Is `/healthz` returning non-200? → container or load balancer issue
- [ ] Is `/healthz` slow (>300ms)? → resource constraint or dependency issue
- [ ] Is the static site affected? → S3/CloudFront issue
- [ ] Is it one AZ or both? → Check ECS task count per AZ

```bash
# Check ECS service health
aws ecs describe-services \
  --cluster charis-api \
  --services charis-api \
  --region us-east-1 \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,pending:pendingCount}'

# Check recent container logs (last 100 lines)
aws logs tail /ecs/charis-api --since 15m --region us-east-1
```

### Minute 5–10: Triage root cause

**Recent deployment?**
```bash
# Check when the last ECS task definition was registered
aws ecs list-task-definitions --family-prefix charis-api --sort DESC --max-items 5
```

**Resource exhaustion?**
```bash
# Check CloudWatch metrics for CPU and memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=charis-api Name=ClusterName,Value=charis-api \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average
```

**Spike in errors?**
```bash
# Check ALB 5xx count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Sum
```

### Minute 10–15: Decide and act

| Situation | Action |
|-----------|--------|
| Bad deployment | Rollback (see below) |
| Resource exhaustion | Scale up tasks immediately |
| Dependency failure | Check if external — escalate or implement circuit breaker |
| Infrastructure issue | Check AWS Service Health Dashboard |

---

## Rollback Steps

### Production — AWS ECS (one command)

```bash
# Get the previous stable task definition ARN
PREV_TASK_DEF=$(aws ecs describe-services \
  --cluster charis-api \
  --services charis-api \
  --query 'services[0].taskDefinition' \
  --output text)

# Roll back one revision
PREV_REVISION=$(echo $PREV_TASK_DEF | sed 's/:[0-9]*$//'):$(($(echo $PREV_TASK_DEF | grep -o '[0-9]*$') - 1))

aws ecs update-service \
  --cluster charis-api \
  --service charis-api \
  --task-definition $PREV_REVISION \
  --force-new-deployment

echo "Rollback initiated — monitor health at https://<cloudfront-domain>/healthz"
```

**Note:** ECS deployment circuit breaker (`rollback = true`) triggers this automatically on a failed health check during deployment. Manual steps above are for post-deployment rollback.

### Staging — Azure Web App (one command)

```bash
az webapp config container set \
  --name charis-api-staging \
  --resource-group charis-api-staging-rg \
  --docker-custom-image-name <ECR_REGISTRY>/charis-api:<last-good-sha-tag>
```

### Terraform State Rollback (infrastructure change caused the issue)

```bash
# Restore previous Terraform state from S3 versioning
aws s3api list-object-versions \
  --bucket charis-tf-state-prod \
  --prefix prod-aws/terraform.tfstate

# Restore a specific version
aws s3api get-object \
  --bucket charis-tf-state-prod \
  --key prod-aws/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restore

# Apply previous plan
cd infra/envs/prod-aws
terraform apply -var="image_tag=<last-good-tag>"
```

---

## DR — CloudFront / CDN Origin Failover

CloudFront supports origin failover groups. If the primary ALB is unhealthy for 3 consecutive health checks:

1. CloudFront automatically switches to the secondary origin
2. Suitable secondary: a static maintenance page in S3 (`/maintenance/index.html`)
3. To enable: add an Origin Group in CloudFront with the ALB as primary and the S3 bucket as failover

**State considerations during failover:**
- ECS is stateless — tasks can be replaced freely
- Static assets in S3 are not affected
- No database exists — no state consistency concern
- Fargate Spot interruptions are handled by the 70/30 on-demand mix and autoscaling

---

## Comms Template

### Initial notification (within 5 minutes of detection)

```
[INCIDENT STARTED] charis-api — <prod|staging>
Time detected: 2026-03-05 14:32 UTC
Impact: <brief description — e.g. "API returning 502, ~100% of requests affected">
Status: Investigating
Next update: 14:47 UTC
On-call: <your name>
```

### Update (every 15 minutes until resolved)

```
[INCIDENT UPDATE] charis-api — <prod|staging>
Time: 14:47 UTC
Status: <Investigating | Identified | Mitigating | Resolved>
Finding: <what we know — e.g. "bad container image from sha-abc1234 deployment">
Action: <what we are doing — e.g. "rolling back to sha-xyz9876">
ETA: <estimated resolution time>
```

### Resolution

```
[INCIDENT RESOLVED] charis-api — <prod|staging>
Time resolved: 15:01 UTC
Duration: 29 minutes
Root cause: <brief — e.g. "memory leak in sha-abc1234, triggered OOM kill under load">
Fix: <e.g. "rolled back to sha-xyz9876, opened bug ticket #123">
Postmortem: to be published within 48 hours
```

---

## Postmortem Template

```markdown
# Postmortem — [Incident Title]

**Date:** YYYY-MM-DD  
**Duration:** X minutes  
**Severity:** P1 / P2 / P3  
**Author:** [name]

## Summary
One paragraph: what happened, what was affected, how it was fixed.

## Timeline (UTC)
| Time | Event |
|------|-------|
| HH:MM | First alert fired |
| HH:MM | On-call paged |
| HH:MM | Root cause identified |
| HH:MM | Rollback initiated |
| HH:MM | Service restored |

## Root Cause
Describe the technical cause. Avoid blame.

## Contributing Factors
- Factor 1
- Factor 2

## What Went Well
- Fast rollback due to ECS circuit breaker
- Health gates caught the issue before full rollout

## Action Items
| Action | Owner | Due |
|--------|-------|-----|
| Add unit test for memory leak | dev team | +3 days |
| Add memory utilisation alert | platform | +1 day |

## Lessons Learned
What would have prevented or shortened this incident?
```

---

## Backup & Recovery (if DB were present)

Since this deployment does not include a database, backup procedures are documented as a template for when RDS is provisioned:

**Frequency:** Daily automated snapshots (RDS automated backups, 7-day retention)  
**Retention:** 7 days automated + monthly manual snapshot kept for 90 days  
**Recovery procedure:**
1. Identify restore point in RDS Console → Automated backups
2. `aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier <id> --target-db-instance-identifier <restored-id> --restore-time <ISO-8601>`
3. Update ECS task definition with new database endpoint
4. Run database migration scripts (if schema changed)
5. Validate with integration test against `/healthz`

**RTO target:** < 1 hour  
**RPO target:** < 24 hours (daily snapshot)
