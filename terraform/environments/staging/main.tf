locals {
  name_prefix = "${var.environment}-pharma"
  tags = {
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

# ---------------------------------------------------------------- KMS ---
resource "aws_kms_key" "this" {
  description             = "${local.name_prefix} data platform CMK (S3, MWAA, Secrets Manager, SNS)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name_prefix}-cmk"
  target_key_id = aws_kms_key.this.key_id
}

# ----------------------------------------------------------------- S3 ---
module "s3_raw" {
  source                       = "../../modules/s3"
  bucket_name                  = "${local.name_prefix}-raw-landing-${random_id.bucket_suffix.hex}"
  kms_key_arn                  = aws_kms_key.this.arn
  versioning_enabled           = true
  lifecycle_glacier_after_days = 180
  force_destroy                = var.environment != "prod"
  tags                         = local.tags
}

module "s3_mwaa" {
  source                       = "../../modules/s3"
  bucket_name                  = "${local.name_prefix}-mwaa-${random_id.bucket_suffix.hex}"
  kms_key_arn                  = aws_kms_key.this.arn
  versioning_enabled           = true
  lifecycle_glacier_after_days = 0
  force_destroy                = var.environment != "prod"
  tags                         = local.tags
}

# ---------------------------------------------------------------- VPC ---
module "vpc" {
  source                = "../../modules/vpc"
  name_prefix            = local.name_prefix
  azs                     = var.azs
  vpc_cidr                = "10.20.0.0/16"
  public_subnet_cidrs     = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnet_cidrs    = ["10.20.10.0/24", "10.20.11.0/24"]
  tags                    = local.tags
}

# ---------------------------------------------------------------- IAM ---
module "iam" {
  source                        = "../../modules/iam"
  name_prefix                   = local.name_prefix
  raw_bucket_arn                = module.s3_raw.bucket_arn
  mwaa_bucket_arn                = module.s3_mwaa.bucket_arn
  kms_key_arn                    = aws_kms_key.this.arn
  github_org                     = var.github_org
  github_repo                    = var.github_repo
  snowflake_storage_integration_iam_user_arn = var.snowflake_storage_integration_iam_user_arn
  snowflake_storage_integration_external_id  = var.snowflake_storage_integration_external_id
  tags                            = local.tags
}

# --------------------------------------------------------------- MWAA ---
module "mwaa" {
  source                 = "../../modules/mwaa"
  name_prefix             = local.name_prefix
  dags_s3_bucket_arn      = module.s3_mwaa.bucket_arn
  dags_s3_bucket_id       = module.s3_mwaa.bucket_id
  execution_role_arn      = module.iam.mwaa_execution_role_arn
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  security_group_ids      = [module.vpc.mwaa_security_group_id]
  kms_key_arn              = aws_kms_key.this.arn
  environment_class        = "mw1.small"
  min_workers              = 1
  max_workers              = 5
  alert_email_endpoint     = var.mwaa_alert_email
  tags                     = local.tags
}

# ----------------------------------------------------------- Snowflake --
module "snowflake" {
  source                        = "../../modules/snowflake"
  env                            = var.environment
  storage_integration_role_arn   = module.iam.snowflake_storage_integration_role_arn
  raw_bucket_s3_uri              = "s3://${module.s3_raw.bucket_id}/"
  loader_role_users              = var.snowflake_loader_users
  transformer_role_users         = var.snowflake_transformer_users
  analyst_role_users             = var.snowflake_analyst_users
}
