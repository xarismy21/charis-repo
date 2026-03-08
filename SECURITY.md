# Security Baseline

This document describes the security controls applied across all environments, their enforcement points, and planned next steps.

---

## 1. Identity & Access Management

### GitHub OIDC → AWS (no stored credentials)

GitHub Actions authenticates to AWS using OpenID Connect federation — no long-lived access keys exist anywhere.

**How it works:**
- GitHub generates a short-lived OIDC token per workflow run
- AWS IAM trusts tokens from `token.actions.githubusercontent.com`
- The token is exchanged for temporary STS credentials scoped to a single IAM role
- Credentials expire after 1 hour automatically

**Enforcement point:** `infra/modules/iam-oidc/main.tf` — the trust policy restricts federation to a specific repo (`repo:<org>/<repo>:*`). A forked repo cannot assume the role.

### Least-Privilege Roles

| Role | Permissions |
|------|-------------|
| `charis-api-github-deploy` | ECR push, ECS update-service, S3 state read/write, CloudFront invalidation only |
| `charis-api-ecs-execution` | `AmazonECSTaskExecutionRolePolicy` (AWS managed, pull image + write logs) |
| `charis-api-ecs-task` | CloudWatch log stream write only |

**Next step:** Implement IAM Access Analyzer to detect unused permissions and tighten further after one sprint of production traffic.

---

## 2. Secrets Management

### AWS — No secrets in environment variables

Secrets are stored in AWS Secrets Manager and injected at runtime via ECS task secrets integration (not environment variables). This means secrets never appear in the ECS task definition JSON, CloudTrail logs, or console.

**Pattern:**

```hcl
# In task definition (future extension)
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:...:secret:charis-api/db-password"
  }
]
```

### Azure — Key Vault (planned)

The Web App uses a System-Assigned Managed Identity. Secrets should be stored in Azure Key Vault and referenced as Key Vault references in app settings:

```
@Microsoft.KeyVault(SecretUri=https://charis-kv.vault.azure.net/secrets/db-password/)
```

**Current state:** No application secrets exist (the demo API has none). The pattern is wired and documented for when secrets are needed.

---

## 3. Container Image Security

### Image Scanning (Trivy)

Every image built in CI is scanned by Trivy before it can be pushed to ECR.

- **Gate:** Unfixed CRITICAL or HIGH CVEs fail the pipeline (`exit-code: "1"`)
- **Scope:** OS packages + Go dependencies
- **Results:** Uploaded to GitHub Security tab as SARIF (visible under repo → Security → Code scanning)

### SBOM Generation (Syft)

A Software Bill of Materials is generated for every image in SPDX-JSON format and stored as a CI artifact for 30 days. This satisfies supply chain transparency requirements.

### Base Image Strategy

The final Docker image uses `scratch` (empty base):
- Zero OS packages = zero OS CVEs
- No shell = no interactive exploit path
- Image size ~6 MB vs ~120 MB for `python:3-slim`
- Process runs as UID 65534 (nobody) — non-root

### ECR Settings

- **Image tag mutability:** `IMMUTABLE` — once pushed, a tag cannot be overwritten
- **Scan on push:** enabled at the registry level as a second layer
- **Encryption:** AES256 at rest

---

## 4. Network & Transport Security

### HTTPS Everywhere

| Layer | Enforcement |
|-------|-------------|
| CloudFront | HTTP → HTTPS 301 redirect at CDN edge |
| ALB listener | Port 80 redirects to port 443 (HTTP_301) |
| Azure CDN | HTTP → HTTPS redirect delivery rule |
| Azure Web App | `https_only = true` |
| TLS version | TLSv1.2 minimum everywhere (TLS 1.3 preferred) |

### Security Headers (CloudFront Response Headers Policy)

Applied at CDN layer — no application code changes required:

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `X-XSS-Protection` | `1; mode=block` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |

### ALB Origin Verification

CloudFront adds a custom `X-Origin-Verify` header (random 32-character secret) to every request forwarded to the ALB. The ALB can be configured to reject requests missing this header, preventing direct access to the ALB DNS name and bypassing CloudFront/WAF.

---

## 5. WAF Configuration

**Managed rule groups enabled:**

| Rule Group | Purpose | Exclusions |
|------------|---------|------------|
| `AWSManagedRulesCommonRuleSet` | OWASP Top 10 (SQLi, XSS, path traversal) | `SizeRestrictions_BODY` counted (not blocked) — avoids false positives on JSON payloads |
| `AWSManagedRulesKnownBadInputsRuleSet` | Log4j, Spring4Shell, known exploit patterns | None |

**WAF is scoped to CloudFront** — all traffic passes through WAF before reaching the origin.

**Monitoring:** All WAF decisions (ALLOW/BLOCK/COUNT) are logged to CloudWatch under the `aws-waf-logs-*` namespace.

**Next step:** Add rate-based rule (e.g. 1000 requests per 5 minutes per IP) to mitigate scraping and credential stuffing.

---

## 6. Next Steps (Priority Order)

1. **Rate limiting rule in WAF** — protects against brute force and DDoS at zero additional infrastructure cost
2. **AWS Secrets Manager rotation** — enable automatic 30-day rotation for any future database credentials
3. **VPC Flow Logs** — enable for the ECS VPC to detect lateral movement or unexpected egress
4. **GuardDuty** — enable at the AWS account level (flat $3–5/month for this workload size)
5. **Azure Defender for Containers** — enable on the subscription for runtime threat detection
6. **Dependabot / Renovate** — automate Go module and base image updates to reduce CVE exposure window
