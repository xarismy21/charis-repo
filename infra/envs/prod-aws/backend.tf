# Remote state stored in S3 with DynamoDB locking.
# Bootstrap: run scripts/bootstrap-tf-state.sh before the first terraform init.
terraform {
  backend "s3" {
    bucket         = "charis-tf-state-prod"
    key            = "prod-aws/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "charis-tf-locks"
  }

  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# WAF must be in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
