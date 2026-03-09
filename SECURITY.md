# Security Baseline

This document describes the security controls applied across all environments,
their enforcement points, and known gaps with remediation plans.

---

## 1. Identity & Access Management

### GitHub OIDC → AWS (no stored credentials)

GitHub Actions authenticates to AWS using OpenID Connect federation — no long-lived access keys exist anywhere.

- GitHub generates a short-lived OIDC token per workflow run
- AWS IAM trusts tokens from `token.actions.githubusercontent.com`
- Token exchanged for temporary STS credentials scoped to a single IAM role
- Credentials expire after 1 hour automatically

**Enforcement point:** `infra/modules/iam-oidc/main.tf` — trust policy restricts to `repo:xarismy21/charis-repo:*`. A forked repo cannot assume the role.

### GitHub OIDC → Azure (Workload Identity Federation)

Azure authentication uses Workload Identity Federation — no `AZURE_CREDENTIALS` JSON secret is stored anywhere.

- App registration `charis-github-deploy` in Azure AD
- Federated credential scoped to `repo:xarismy21/charis-repo:ref:refs/heads/main`
- GitHub Actions authenticates with `client-id`, `tenant-id`, `subscription-id` (not a secret)
- No client secret was ever created on the app registration

### Least-Privilege Roles

| Role | Permissions |
|---|---|
| `charis-api-github-deploy` (AWS) | ECR push, ECS update-service, S3 state read/write, CloudFront invalidation only |
| `charis-github-deploy` (Azure) | Contributor on subscription — assumed via Workload Identity Federation |
| `charis-api-ecs-execution` | `AmazonECSTaskExecutionRolePolicy` (pull image + write logs) |
| `charis-api-ecs-task` | CloudWatch log stream write only |

---

## 2. Secrets Management

### AWS — No secrets in environment variables

Secrets stored in AWS Secrets Manager, injected at runtime via ECS task secrets integration.

```hcl
# Pattern for future secrets
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:...:secret:charis-api/db-password"
  }
]
