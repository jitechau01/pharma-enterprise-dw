terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.94"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "pharma-enterprise-dw"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Auth via SNOWFLAKE_* environment variables (or key-pair auth) is preferred
# over hardcoding here -- see terraform.tfvars.example for the full list of
# required vars and docs/runbook.md for the recommended key-pair auth setup.
provider "snowflake" {
  role = "LEAD_ROLE"
}
