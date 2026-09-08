# Remote state in S3 with a DynamoDB lock table. Bootstrap these two
# resources by hand (or via a one-time `terraform apply` with a local
# backend) before pointing this block at them -- see docs/runbook.md
# "Bootstrapping remote state".
terraform {
  backend "s3" {
    bucket         = "pharma-dw-tfstate-prod"       # replace with your bootstrap bucket
    key            = "pharma-enterprise-dw/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pharma-dw-tfstate-lock-prod"
    encrypt        = true
  }
}
