# Observability — Dashboards & Alert Rules

Covers: SLO definitions, CloudWatch dashboard stub, Application Insights queries, and three alert rules.

---

## SLO Definitions

### SLO 1 — Monthly Availability 99.9% (API)

- **Target:** ≤ 43.8 minutes downtime per month (error budget)
- **Signal:** `HTTPCode_Target_5XX_Count / RequestCount < 0.001` as measured by ALB
- **Window:** 30-day rolling
- **Burn rate alert:** Fire when 1-hour error rate is 14× the monthly budget (early warning before SLO is breached)

### SLO 2 — P95 Latency ≤ 300ms on /healthz

- **Target:** 95th percentile response time ≤ 300ms as measured through ALB
- **Signal:** `TargetResponseTime p95 ≤ 0.3` over 5-minute windows
- **Window:** 5-minute evaluation, 3 consecutive periods before alert fires

---

## CloudWatch Dashboard (JSON stub)

Deploy with AWS CLI:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name charis-api-prod \
  --dashboard-body file://docs/cloudwatch-dashboard.json \
  --region us-east-1
```

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "Request Rate & Error Rate",
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "<ALB_NAME>",
           {"stat": "Sum", "period": 60, "label": "Total Requests"}],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "<ALB_NAME>",
           {"stat": "Sum", "period": 60, "label": "5xx Errors", "color": "#d62728"}],
          ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", "<ALB_NAME>",
           {"stat": "Sum", "period": 60, "label": "4xx Errors", "color": "#ff7f0e"}]
        ],
        "view": "timeSeries",
        "period": 60,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "P95 Latency (ms) — SLO: ≤ 300ms",
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "<ALB_NAME>",
           {"stat": "p95", "period": 60, "label": "P95 Latency"}],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "<ALB_NAME>",
           {"stat": "p50", "period": 60, "label": "P50 Latency"}]
        ],
        "annotations": {
          "horizontal": [{"value": 0.3, "label": "SLO threshold (300ms)", "color": "#d62728"}]
        },
        "view": "timeSeries",
        "period": 60,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "ECS Task Health",
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "charis-api", "ClusterName", "charis-api",
           {"stat": "Average", "label": "CPU %"}],
          ["AWS/ECS", "MemoryUtilization", "ServiceName", "charis-api", "ClusterName", "charis-api",
           {"stat": "Average", "label": "Memory %"}]
        ],
        "view": "timeSeries",
        "period": 60,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "CloudFront Cache Hit Rate",
        "metrics": [
          ["AWS/CloudFront", "CacheHitRate", "DistributionId", "<DISTRIBUTION_ID>",
           {"stat": "Average", "label": "Cache Hit %"}],
          ["AWS/CloudFront", "Requests", "DistributionId", "<DISTRIBUTION_ID>",
           {"stat": "Sum", "label": "Total Requests"}]
        ],
        "view": "timeSeries",
        "period": 300,
        "region": "us-east-1"
      }
    }
  ]
}
```

---

## Terraform Alternative — Dashboard as Code

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "charis-api-prod"
  dashboard_body = templatefile("${path.module}/dashboard.json.tpl", {
    alb_name          = module.ecs.alb_arn
    distribution_id   = module.cdn.cloudfront_distribution_id
    region            = var.aws_region
  })
}
```

---

## Three Alert Rules

### Alert 1 — SLO Burn: 5-Minute Error Rate > 2%

```hcl
resource "aws_cloudwatch_metric_alarm" "slo_error_rate" {
  alarm_name          = "charis-api-slo-burn-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2
  alarm_description   = "SLO burn alert: 5-minute error rate exceeds 2% — investigate immediately"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors / MAX([errors, requests]) * 100"
    label       = "5xx Error Rate %"
    return_data = true
  }
  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = "<ALB_ARN_SUFFIX>" }
      period      = 300
      stat        = "Sum"
    }
  }
  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = { LoadBalancer = "<ALB_ARN_SUFFIX>" }
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
```

### Alert 2 — SLO Breach: P95 Latency > 300ms

```hcl
resource "aws_cloudwatch_metric_alarm" "slo_latency" {
  alarm_name          = "charis-api-slo-p95-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3       # 3 × 5-minute windows = 15 minutes sustained breach
  threshold           = 0.3     # 300ms in seconds
  alarm_description   = "SLO breach: P95 latency on ALB exceeds 300ms for 15 minutes"
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"
  dimensions  = { LoadBalancer = "<ALB_ARN_SUFFIX>" }
  period      = 300
  extended_statistic = "p95"

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### Alert 3 — Daily Cost Threshold (80% of $10/day budget)

```hcl
resource "aws_budgets_budget" "daily_alert" {
  name         = "charis-api-daily-cost"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ops@example.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["ops@example.com"]
  }
}
```

---

## Azure — Application Insights Queries (Log Analytics)

### Availability over last 24 hours

```kusto
requests
| where timestamp > ago(24h)
| summarize
    total = count(),
    failed = countif(success == false),
    availability = (1.0 - (countif(success == false) * 1.0 / count())) * 100
| project availability, total, failed
```

### P95 latency by hour

```kusto
requests
| where timestamp > ago(24h) and name == "GET /healthz"
| summarize p95_ms = percentile(duration, 95) by bin(timestamp, 1h)
| render timechart
```

### Top error messages in the last hour

```kusto
exceptions
| where timestamp > ago(1h)
| summarize count() by outerMessage
| order by count_ desc
| take 10
```
