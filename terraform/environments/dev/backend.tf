terraform {
  backend "s3" {
    bucket         = "pharma-dw-tfstate-dev-cloud-14295"
    key            = "pharma-enterprise-dw/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pharma-dw-tfstate-lock-dev"
    encrypt        = true
  }
}
