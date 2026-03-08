## Terraform Notes

During `terraform plan` you may see warnings similar to:

Warning: Value for undeclared variable
container_registry
container_registry_password

These variables are intentionally not declared in `variables.tf` because they are normally injected by the CI/CD pipeline as environment variables or secrets.

The warnings do not affect Terraform validation or planning and can be safely ignored for local validation.
