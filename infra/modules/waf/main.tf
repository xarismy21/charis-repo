# WAF v2 WebACL scoped for CloudFront (must be us-east-1)
resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }
  # Rate limit — block IPs exceeding 1000 requests per 5 minutes
  # Priority 0 = evaluated first, before all managed rule groups
  # Protects against brute force, credential stuffing, and scraping
  rule {
    name     = "RateLimitPerIP"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }
  # AWS managed core rule set — covers OWASP Top 10
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that commonly break healthz endpoints
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
  count {}
}
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs (SQLi, XSS, etc.)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }

  tags = var.tags
}


