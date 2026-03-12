locals {
  name        = "charis-api"
  environment = "prod"

  common_tags = {
    Project     = "charis-api"
    Environment = "prod"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

# ── ECR ──────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  name = local.name
  tags = local.common_tags
}

# ── WAF (must be us-east-1 for CloudFront) ───────────────────────────────────
module "waf" {
  source = "../../modules/waf"
  providers = {
    aws = aws.us_east_1
  }

  name = "${local.name}-prod"
  tags = local.common_tags
}

# ── ECS Fargate + ALB ────────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs-fargate"

  name        = local.name
  environment = local.environment

  ecr_repository_url = module.ecr.repository_url
  image_tag          = var.image_tag

  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  task_cpu    = 256
  task_memory = 512
  desired_count = 2
  min_count     = 1
  max_count     = 10

  acm_certificate_arn = var.acm_certificate_arn

  tags = local.common_tags
}

# ── S3 + CloudFront ──────────────────────────────────────────────────────────
module "cdn" {
  source = "../../modules/s3-cloudfront"
  providers = {
    aws = aws.us_east_1
  }

  name        = local.name
  environment = local.environment
  bucket_name = "charis-static-prod-${data.aws_caller_identity.current.account_id}"

  waf_web_acl_arn      = module.waf.web_acl_arn
  alb_dns_name         = module.ecs.alb_dns_name
  origin_verify_secret = random_password.origin_verify.result

  acm_certificate_arn = var.acm_certificate_arn
  domain_aliases      = var.domain_aliases

  tags = local.common_tags
}

resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# ── IAM + GitHub OIDC ────────────────────────────────────────────────────────
module "iam_oidc" {
  source = "../../modules/iam-oidc"

  name        = local.name
  github_org  = var.github_org
  github_repo = var.github_repo

  ecr_repository_arns = [module.ecr.repository_arn]
  ecs_role_arns = [
    module.ecs.ecs_task_role_arn,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name}-ecs-execution"
  ]

  tf_state_bucket = "charis-tf-state-prod"
  tf_lock_table   = "charis-tf-locks"

  tags = local.common_tags
}

# ── CloudWatch Alarms ────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_error_rate" {
  alarm_name          = "${local.name}-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2
  alarm_description   = "SLO burn: 5-minute error rate > 2%"
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
      dimensions  = { LoadBalancer = module.ecs.alb_arn }
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = { LoadBalancer = module.ecs.alb_arn }
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
}

resource "aws_cloudwatch_metric_alarm" "p95_latency" {
  alarm_name          = "${local.name}-p95-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 300
  alarm_description   = "SLO breach: P95 latency on /healthz > 300ms"
  treat_missing_data  = "notBreaching"

  namespace          = "AWS/ApplicationELB"
  metric_name        = "TargetResponseTime"
  dimensions         = { LoadBalancer = module.ecs.alb_arn }
  period             = 300
  extended_statistic = "p95"

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
}

resource "aws_budgets_budget" "daily" {
  name         = "${local.name}-daily-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "DAILY"

  dynamic "notification" {
    for_each = length(var.budget_alert_emails) > 0 ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_alert_emails
    }
  }
}

data "aws_caller_identity" "current" {}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "budget_alert_emails" {
  description = "Email addresses for daily budget alerts"
  type        = list(string)
  default     = []
}
