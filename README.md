# charis-repo DevOps Assessment #Papaoikonomou Charis#

## Quick Start

Clone repository

git clone https://github.com/xarismy21/charis-repo

cd charis-repo

## Build API

cd api

go build

## Build container

docker build -t charis-api ./docker

## Validate infrastructure

cd terraform

terraform init

terraform plan
## Design Decisions

This project demonstrates a simple DevOps pipeline including:

- Go API service
- Docker containerization
- Terraform infrastructure
- CI pipeline with GitHub Actions

Infrastructure is defined using Terraform to allow reproducible deployments.

Monitoring and logging can be extended with cloud-native tools such as:

- AWS CloudWatch
- Azure Application Insights
- Log Analytics

## Production Improvements

If this were production infrastructure, the following improvements would be implemented:

- Use Terraform remote state (S3 or Azure Storage)
- Add secret management using AWS Secrets Manager or Azure Key Vault
- Enable CI security scanning (Trivy / Snyk)
- Implement automated deployments via CI/CD pipeline
- Add monitoring alerts and dashboards
- Add cost controls and budget alerts

## Notes

Some infrastructure components are simplified for the purpose of this assessment.
