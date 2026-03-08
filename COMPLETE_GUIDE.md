# Complete Step-by-Step Guide — charis-repo Assessment
### From zero to submitted — every click, every command, in order

---

## How to Use This Guide

Read each phase fully before starting it. Every step is numbered. Every command is copy-paste ready.
When a step says "replace X with Y", that means type your actual value — do not copy the placeholder.

**Total time estimate:** 6–8 hours across the phases below.

---

## Phase Overview

| Phase | What You Do | Time |
|-------|-------------|------|
| A | Local machine setup | 30 min |
| B | GitHub — create repo and push code | 20 min |
| C | AWS — bootstrap state and first Terraform apply | 45 min |
| D | Azure — bootstrap state and first Terraform apply | 30 min |
| E | GitHub Actions — configure secrets and test CI | 20 min |
| F | Azure DevOps — set up pipeline with approvals | 30 min |
| G | End-to-end test — push a commit and watch everything run | 30 min |
| H | Technical Q&A — answer the 6 short questions | 30 min |
| I | Final submission — repo check and README polish | 20 min |

---

## Phase A — Local Machine Setup

### A1. Install Git

1. Open your browser and go to **https://git-scm.com/download/win**
2. Download the installer and run it — accept all defaults
3. Open **PowerShell** (press `Win + X` → Windows PowerShell) and verify:

```powershell
git --version
# Expected output: git version 2.44.x or higher
```

### A2. Install Terraform

1. Go to **https://developer.hashicorp.com/terraform/install**
2. Under **Windows**, click **AMD64** to download the zip file
3. Extract the zip — you get a file called `terraform.exe`
4. Move `terraform.exe` to `C:\Windows\System32\` (this makes it available everywhere)
5. Verify:

```powershell
terraform --version
# Expected output: Terraform v1.6.x or higher
```

### A3. Install Docker Desktop

1. Go to **https://www.docker.com/products/docker-desktop/**
2. Click **Download for Windows**
3. Run the installer — accept defaults
4. After install, Docker Desktop will appear in your taskbar (whale icon)
5. Wait until it says **"Docker Desktop is running"**
6. Verify:

```powershell
docker --version
# Expected output: Docker version 26.x.x
```

### A4. Install AWS CLI

1. Go to **https://aws.amazon.com/cli/**
2. Click **Install AWS CLI** → **Windows** → download the MSI installer
3. Run the MSI — accept all defaults
4. Verify:

```powershell
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x Windows/...
```

### A5. Install Azure CLI

1. Go to **https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows**
2. Download and run the MSI installer
3. Verify:

```powershell
az --version
# Expected output: azure-cli 2.x.x ...
```

### A6. Install Go (optional — only needed to run the API locally without Docker)

1. Go to **https://go.dev/dl/**
2. Download the Windows installer (`.msi`)
3. Run it — accept defaults
4. Verify:

```powershell
go version
# Expected output: go version go1.22.x windows/amd64
```

### A7. Configure AWS CLI

You need an AWS access key. To create one:

1. Log into **https://console.aws.amazon.com**
2. Click your account name (top right) → **Security credentials**
3. Scroll to **Access keys** → click **Create access key**
4. Choose **Command Line Interface (CLI)** → confirm → click **Create**
5. **Copy both the Access Key ID and the Secret Access Key** — you will not see the secret again

Now configure the CLI:

```powershell
aws configure
# It will ask you four questions:
# AWS Access Key ID: paste your key
# AWS Secret Access Key: paste your secret key
# Default region name: us-east-1
# Default output format: json
```

Verify it works:

```powershell
aws sts get-caller-identity
# Expected output: your account ID and username in JSON
```

### A8. Configure Azure CLI

```powershell
az login
# A browser window will open — log in with your Azure account
# After login, the terminal will show your subscription details
```

Note your Subscription ID from the output — you will need it later:

```powershell
az account show --query id --output tsv
# Copy this value — example: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Phase B — GitHub Setup

### B1. Create the GitHub Repository

1. Open your browser and go to **https://github.com**
2. Log in with your account
3. Click the **+** button (top right) → **New repository**
4. Fill in:
   - **Repository name:** `charis-repo`
   - **Description:** `Multi-environment DevOps pipeline — Go API on AWS ECS + Azure Web App`
   - **Visibility:** ✓ **Public** (required by assessment)
   - **Initialize this repository with:** leave all checkboxes **unchecked**
5. Click **Create repository**
6. GitHub shows you a page with the repo URL — copy it (looks like `https://github.com/YOUR_USERNAME/charis-repo.git`)

### B2. Open Cursor (your IDE) and navigate to the project folder

In PowerShell:

```powershell
cd C:\Users\charalap\charis-repo
```

### B3. Initialise Git and push the project

```powershell
# Initialise a git repository in the project folder
git init

# Stage all files
git add .

# Create the first commit
git commit -m "feat: initial project structure with Go API, Terraform, and CI/CD pipelines"

# Connect to GitHub (replace YOUR_USERNAME with your actual GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/charis-repo.git

# Push to GitHub
git branch -M main
git push -u origin main
```

After this, refresh your GitHub page — you should see all the files.

### B4. Enable GitHub Actions

1. In your GitHub repo, click the **Actions** tab
2. If it asks "Get started with GitHub Actions", click **I understand my workflows, go ahead and enable them**
3. You should now see the workflow file listed (it won't run yet because secrets are missing)

### B5. Set up Branch Protection (best practice)

1. In your GitHub repo → **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Under **Branch name pattern**, type: `main`
4. Check these boxes:
   - ✓ **Require a pull request before merging**
   - ✓ **Require status checks to pass before merging**
   - ✓ **Require branches to be up to date before merging**
5. Click **Create**

---

## Phase C — AWS Setup

### C1. Bootstrap Terraform State (S3 + DynamoDB)

These resources must be created **before** running `terraform init` for the first time.
Open PowerShell and run these commands **one by one**:

```powershell
# Create the S3 bucket for Terraform state
aws s3api create-bucket `
  --bucket charis-tf-state-prod `
  --region us-east-1

# Enable versioning — protects you if state gets corrupted
aws s3api put-bucket-versioning `
  --bucket charis-tf-state-prod `
  --versioning-configuration Status=Enabled

# Enable encryption on the bucket
aws s3api put-bucket-encryption `
  --bucket charis-tf-state-prod `
  --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'

# Block all public access to the state bucket
aws s3api put-public-access-block `
  --bucket charis-tf-state-prod `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create the DynamoDB table for state locking (prevents two people applying at the same time)
aws dynamodb create-table `
  --table-name charis-tf-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region us-east-1
```

Verify both were created:

```powershell
aws s3api head-bucket --bucket charis-tf-state-prod
# No output = success

aws dynamodb describe-table --table-name charis-tf-locks --query "Table.TableStatus"
# Expected: "ACTIVE"
```

### C2. First Terraform Apply — AWS Production

```powershell
# Navigate to the prod-aws environment directory
cd C:\Users\charalap\charis-repo\infra\envs\prod-aws

# Copy the example variables file and fill it in
Copy-Item terraform.tfvars.example terraform.tfvars
```

Now open the file `terraform.tfvars` in any text editor (Notepad is fine) and edit it:

```
aws_region  = "us-east-1"
github_org  = "YOUR_GITHUB_USERNAME"   ← replace this
github_repo = "charis-repo"
image_tag   = "sha-000000"

acm_certificate_arn = ""
domain_aliases      = []

alarm_sns_arn       = ""
budget_alert_emails = ["YOUR_EMAIL@gmail.com"]   ← replace this

pause_deploy = false
```

Save the file, then:

```powershell
# Download all Terraform providers (first run takes ~2 minutes)
terraform init

# Preview what Terraform will create — read the output carefully
terraform plan -var="image_tag=sha-000000"

# Create all AWS infrastructure (takes 10–15 minutes)
terraform apply -var="image_tag=sha-000000"
# Terraform will ask: "Do you want to perform these actions?"
# Type: yes
# Press Enter
```

**When it finishes**, collect these output values — you need them later:

```powershell
terraform output
```

Copy down these values:
- `ecr_repository_url` — your container registry URL
- `cloudfront_domain` — your public website URL
- `cloudfront_distribution_id` — needed for cache invalidation
- `github_deploy_role_arn` — needed for GitHub secrets

### C3. Set Up the GitHub OIDC Role in AWS

The `terraform apply` above already created the OIDC provider. But you need to verify it:

1. Open **https://console.aws.amazon.com**
2. Go to **IAM** → **Identity providers**
3. You should see `token.actions.githubusercontent.com` listed
4. Go to **IAM** → **Roles** → search for `charis-api-github-deploy`
5. Click the role — verify the trust policy shows your GitHub username

### C4. Test ECR Access

```powershell
# Log Docker into your ECR registry
# Replace ACCOUNT_ID with your 12-digit AWS account ID (visible in the top-right of AWS console)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Expected output: "Login Succeeded"
```

### C5. Manually Build and Push the First Image

This is needed to give ECS something to pull before CI is wired up:

```powershell
cd C:\Users\charalap\charis-repo\app

# Build the image
docker build -t charis-api:sha-000000 .

# Tag it for ECR (replace ACCOUNT_ID)
docker tag charis-api:sha-000000 ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/charis-api:sha-000000

# Push it
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/charis-api:sha-000000
```

### C6. Update ECS with the Real Image

```powershell
cd C:\Users\charalap\charis-repo\infra\envs\prod-aws

# Apply again with the real image tag
terraform apply -var="image_tag=sha-000000"
```

---

## Phase D — Azure Setup

### D1. Bootstrap Terraform State (Azure Storage)

```powershell
# Create a Resource Group for the Terraform state
az group create `
  --name charis-tf-state-rg `
  --location westeurope

# Create a Storage Account (name must be globally unique — if this fails, try a different name)
az storage account create `
  --name charistfstate `
  --resource-group charis-tf-state-rg `
  --location westeurope `
  --sku Standard_LRS `
  --min-tls-version TLS1_2

# Create the container where the state file will live
az storage container create `
  --name tfstate `
  --account-name charistfstate
```

Verify:

```powershell
az storage container list --account-name charistfstate --query "[].name"
# Expected: ["tfstate"]
```

### D2. Create an Azure Service Principal for Terraform and GitHub

```powershell
# Get your subscription ID
$SUBSCRIPTION_ID = az account show --query id --output tsv
echo $SUBSCRIPTION_ID

# Create a service principal with Contributor access
az ad sp create-for-rbac `
  --name "charis-github-deploy" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID" `
  --sdk-auth
```

This outputs a JSON block. **Copy the entire JSON output** — it looks like:

```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  "activeDirectoryEndpointUrl": "...",
  ...
}
```

You will paste this entire JSON as the `AZURE_CREDENTIALS` GitHub secret in Phase E.

### D3. First Terraform Apply — Azure Staging

```powershell
cd C:\Users\charalap\charis-repo\infra\envs\staging-azure

Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```
location     = "westeurope"
image_tag    = "sha-000000"
ecr_registry = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"   ← your ECR registry
ecr_password = ""   ← leave empty for now, will be set later
pause_deploy = false
```

Get the ECR password for Azure to pull from ECR:

```powershell
$ECR_PASSWORD = aws ecr get-login-password --region us-east-1
```

Apply:

```powershell
terraform init

terraform plan `
  -var="image_tag=sha-000000" `
  -var="ecr_password=$ECR_PASSWORD"

terraform apply `
  -var="image_tag=sha-000000" `
  -var="ecr_password=$ECR_PASSWORD"
# Type: yes
```

When done, collect outputs:

```powershell
terraform output
```

Copy:
- `webapp_url` — your staging URL (e.g. `https://charis-api-staging.azurewebsites.net`)
- `webapp_name` — needed for Azure Pipelines
- `resource_group_name` — needed for Azure Pipelines

### D4. Verify Staging is Running

```powershell
# This should return {"status":"ok",...}
curl https://charis-api-staging.azurewebsites.net/healthz
```

> If it takes a minute — that is normal. Azure Web Apps take 1–2 minutes to pull and start the container.

---

## Phase E — GitHub Secrets Setup

### E1. Add Secrets to GitHub

1. In your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each of the following:

**Secret 1:**
- Name: `AWS_DEPLOY_ROLE_ARN`
- Value: the `github_deploy_role_arn` from `terraform output` in Phase C
- Example value: `arn:aws:iam::123456789012:role/charis-api-github-deploy`

**Secret 2:**
- Name: `AZURE_CREDENTIALS`
- Value: the entire JSON block from Phase D2
- Paste the whole JSON as one block

**Secret 3:**
- Name: `ECR_PASSWORD`
- Value: run this in PowerShell and paste the output:

```powershell
aws ecr get-login-password --region us-east-1
```

> Note: ECR tokens expire after 12 hours. For production use, rotate this secret regularly or use OIDC for Azure too.

### E2. Trigger the First CI Run

Make a small change to trigger GitHub Actions:

```powershell
cd C:\Users\charalap\charis-repo

# Add a blank line to the README to trigger a push
Add-Content README.md "`n<!-- ci trigger -->"

git add .
git commit -m "ci: trigger first workflow run"
git push
```

### E3. Watch the Pipeline

1. Go to your GitHub repo → **Actions** tab
2. You should see a workflow run in progress (yellow dot = running)
3. Click on the run to see the live logs
4. Expected flow:
   - **Build · Scan · Push** — ~3–5 minutes
   - **Terraform Plan · AWS Prod** — ~2 minutes
   - **Terraform Plan · Azure Staging** — ~2 minutes
5. All jobs should show green ✓

**If the Trivy scan fails:** it means a CVE was found in the base image. Update the Go version in `app/Dockerfile` to the latest patch version from `https://hub.docker.com/_/golang/tags`.

---

## Phase F — Azure DevOps Pipeline Setup

### F1. Create Azure DevOps Organisation and Project

1. Go to **https://dev.azure.com**
2. Log in with the same account you used for Azure
3. If you have no organisation, click **New organization** → name it `charis-devops` → create
4. Click **New project**:
   - Name: `charis-deploy`
   - Visibility: Private
   - Click **Create**

### F2. Install AWS Toolkit for Azure DevOps

The Azure Pipeline uses an AWS task to run Terraform and AWS CLI commands.

1. In Azure DevOps, click the **shopping bag icon** (top right) → **Browse marketplace**
2. Search for **AWS Toolkit for Azure DevOps**
3. Click the result by Amazon Web Services → **Get it free**
4. Select your organisation → **Install**

### F3. Connect GitHub to Azure DevOps

1. In your Azure DevOps project → **Pipelines** → **Create Pipeline**
2. Select **GitHub** as the code source
3. Azure DevOps will ask you to authorise with GitHub → click **Authorize**
4. Select the repository: `charis-repo`
5. Azure DevOps will find `azure-pipelines.yml` automatically
6. Click **Save** (not Run yet)

### F4. Create the Variable Library Group

1. In Azure DevOps → **Pipelines** → **Library** → **+ Variable group**
2. Name the group: `charis-deploy-secrets`
3. Add the following variables (click the lock icon to mark secrets as secret):

| Variable Name | Value | Secret? |
|---------------|-------|---------|
| `AZURE_SERVICE_CONNECTION` | (set in F5 below) | No |
| `AWS_SERVICE_CONNECTION` | (set in F6 below) | No |
| `AZURE_WEBAPP_NAME` | `charis-api-staging` | No |
| `ECR_REGISTRY` | `ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com` | No |
| `ECR_PASSWORD` | output of `aws ecr get-login-password --region us-east-1` | **Yes** |
| `CLOUDFRONT_DOMAIN` | `https://d1234example.cloudfront.net` | No |
| `CLOUDFRONT_DISTRIBUTION_ID` | from `terraform output cloudfront_distribution_id` | No |
| `TF_STATE_RG` | `charis-tf-state-rg` | No |
| `TF_STATE_SA` | `charistfstate` | No |
| `GITHUB_ORG` | your GitHub username | No |

4. Click **Save**

### F5. Create Azure Service Connection

1. In Azure DevOps → **Project Settings** (bottom left) → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Select **Service principal (automatic)**
4. Select your **Subscription**
5. Leave **Resource group** empty (subscription level)
6. Name the connection: `azure-service-connection`
7. Check **Grant access permission to all pipelines**
8. Click **Save**
9. Go back to the Variable group and set `AZURE_SERVICE_CONNECTION` = `azure-service-connection`

### F6. Create AWS Service Connection

1. Still in **Service connections** → **New service connection** → **AWS**
   (this option appears after installing the AWS Toolkit in F2)
2. Fill in:
   - **Access Key ID:** your AWS access key
   - **Secret Access Key:** your AWS secret key
   - **Connection name:** `aws-service-connection`
3. Click **Save**
4. Go back to the Variable group and set `AWS_SERVICE_CONNECTION` = `aws-service-connection`

### F7. Create Deployment Environments with Approvals

1. In Azure DevOps → **Pipelines** → **Environments**
2. Click **New environment**:
   - Name: `staging`
   - Resource: **None**
   - Click **Create**
3. Click the `staging` environment → **...** (three dots) → **Approvals and checks**
4. Click **+** → **Approvals**
5. Add yourself as an approver → **Save**

Repeat for production:
6. Click **New environment**:
   - Name: `production`
   - Resource: **None**
   - Click **Create**
7. Add yourself as approver (same steps)

### F8. Run the Pipeline

1. In Azure DevOps → **Pipelines** → find `charis-repo`
2. Click **Run pipeline**
3. Fill in the parameters:
   - **Image Tag:** `sha-000000` (or the real SHA from your CI run)
   - **Force rollback:** unchecked
4. Click **Run**
5. The pipeline will pause at the `staging` environment waiting for your approval
6. Click **Review** → **Approve**
7. Watch it deploy to staging, run the health gate, then pause for prod approval
8. Approve for prod as well

---

## Phase G — End-to-End Test

### G1. Verify the Health Endpoints

After both pipelines complete successfully:

```powershell
# Staging (Azure)
curl https://charis-api-staging.azurewebsites.net/healthz
# Expected: {"status":"ok","version":"sha-000000","timestamp":"..."}

# Production (AWS via CloudFront — use your actual domain)
curl https://d1234example.cloudfront.net/healthz
# Expected: {"status":"ok","version":"sha-000000","timestamp":"..."}
```

### G2. Test the Full Pipeline End-to-End

Make a real code change to verify the whole flow works:

```powershell
cd C:\Users\charalap\charis-repo
```

Open `app/main.go` in a text editor. Find this section and update the service name in the root handler to include a version message — just a small, visible change.

```powershell
git add .
git commit -m "feat: add build metadata to root endpoint"
git push
```

Watch:
1. **GitHub Actions** — builds new image with a new sha tag, scans it, pushes to ECR
2. **Azure Pipelines** — (trigger manually) deploy to staging → approve → deploy to prod → approve

### G3. Test Rollback (demonstrate it works)

```powershell
# Get list of task definitions (most recent at top)
aws ecs list-task-definitions --family-prefix charis-api --sort DESC --max-items 3 --region us-east-1

# Force a rollback to the previous task definition (replace ARN with your actual previous one)
aws ecs update-service `
  --cluster charis-api `
  --service charis-api `
  --task-definition arn:aws:ecs:us-east-1:ACCOUNT_ID:task-definition/charis-api:1 `
  --force-new-deployment `
  --region us-east-1

# Watch the service stabilise
aws ecs wait services-stable `
  --cluster charis-api `
  --services charis-api `
  --region us-east-1

echo "Rollback complete"
```

---

## Phase H — Technical Q&A

Open the file `docs/TECHNICAL_QA.md` in the repository — it contains full written answers to all six questions. Review them and make sure you understand and can explain each answer in your own words. Adjust the wording to match your personal communication style.

---

## Phase I — Final Submission Checklist

### I1. Repository Completeness Check

Go through this checklist in your GitHub repo:

- [ ] `app/main.go` — Go API with `/healthz`
- [ ] `app/Dockerfile` — multi-stage build
- [ ] `infra/modules/` — 7 Terraform modules
- [ ] `infra/envs/prod-aws/` — AWS production environment
- [ ] `infra/envs/staging-azure/` — Azure staging environment
- [ ] `.github/workflows/ci.yml` — GitHub Actions pipeline
- [ ] `azure-pipelines.yml` — Azure Pipelines deploy
- [ ] `README.md` — setup and deploy instructions
- [ ] `SECURITY.md` — security controls
- [ ] `ON-CALL.md` — runbook and incident templates
- [ ] `COST_NOTES.md` — trade-offs and cost guardrails
- [ ] `docs/dashboards.md` — SLOs, alerts, dashboard stubs
- [ ] `docs/TECHNICAL_QA.md` — answers to Q1–Q6

### I2. Evidence to Include (optional but impressive)

If you can take screenshots or record a short Loom video:
- A GitHub Actions run showing green CI
- The Trivy scan output (even if empty — shows it ran)
- The Azure Pipelines run with the approval step visible
- The `/healthz` endpoint responding in a browser
- The CloudFront URL loading

Paste screenshot links or a Loom URL at the bottom of the README.

### I3. Final Git Push

```powershell
cd C:\Users\charalap\charis-repo

# Make sure everything is committed
git status
# Should say "nothing to commit, working tree clean"

# If there are uncommitted changes:
git add .
git commit -m "docs: final review and submission preparation"
git push
```

### I4. Share the Repository

The assessment asks for a **public GitHub repository link**.

Your link will be: `https://github.com/YOUR_USERNAME/charis-repo`

Verify it is public:
1. Open the link in a private/incognito browser window (not logged in)
2. You should see the repository without needing to log in

---

## Troubleshooting Common Issues

### "terraform init fails — backend error"

The S3 bucket or DynamoDB table does not exist yet. Make sure Phase C1 completed successfully before running `terraform init`.

### "GitHub Actions fails — credentials error"

The `AWS_DEPLOY_ROLE_ARN` secret is wrong or the OIDC provider was not created. Check:
1. The role ARN is correct in GitHub secrets
2. The IAM role exists in AWS console → IAM → Roles → search `charis-api-github-deploy`

### "Trivy scan fails with CVEs"

```powershell
# Update Go version in app/Dockerfile from golang:1.22-alpine to the latest patch
# Check latest at: https://hub.docker.com/_/golang/tags?name=alpine
# Change the FROM line to e.g. golang:1.22.4-alpine
```

### "Azure Web App shows 503"

The container is still pulling or starting. Wait 2–3 minutes and retry. Check App Service logs:
1. Azure Portal → App Services → `charis-api-staging` → **Log stream**

### "ECS tasks are not starting"

```powershell
# Check service events
aws ecs describe-services `
  --cluster charis-api `
  --services charis-api `
  --query "services[0].events[:5]" `
  --region us-east-1
```

Most common cause: the ECR image tag does not exist. Verify the image was pushed in Phase C5.

### "CloudFront returns 403 on S3 content"

The S3 bucket policy was not applied yet. This happens because the bucket policy depends on the CloudFront distribution ARN. Run `terraform apply` again — Terraform will apply the policy on the second run.

---

## Cost — How to Tear Everything Down

**When you are done with the assessment**, destroy the infrastructure to avoid ongoing charges:

```powershell
# Destroy AWS production
cd C:\Users\charalap\charis-repo\infra\envs\prod-aws
terraform destroy -var="image_tag=sha-000000"
# Type: yes

# Destroy Azure staging
cd C:\Users\charalap\charis-repo\infra\envs\staging-azure
terraform destroy -var="image_tag=sha-000000" -var="ecr_password=placeholder"
# Type: yes

# Optionally delete the state backends
aws s3 rb s3://charis-tf-state-prod --force
aws dynamodb delete-table --table-name charis-tf-locks --region us-east-1
az group delete --name charis-tf-state-rg --yes
```

**Keep the GitHub repo public** — the reviewer needs to see it.
