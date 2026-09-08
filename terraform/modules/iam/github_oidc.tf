# Keyless GitHub Actions -> AWS auth (OIDC), used by the terraform_apply.yml
# and dbt CI workflows instead of long-lived AWS access keys.

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name_prefix}-github-actions-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })
}

# Scoped to what CI actually needs: terraform plan/apply on this project's
# resources, plus S3 sync of dbt/ and airflow/dags/ to the MWAA bucket.
# Tightened further per-environment in real usage (separate roles per env).
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.name_prefix}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = ["*"] # scope to your tfstate bucket ARN in production
      },
      {
        Sid      = "DeployArtifactsToMWAABucket"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [var.mwaa_bucket_arn, "${var.mwaa_bucket_arn}/*"]
      },
      {
        Sid      = "ManageProjectInfra"
        Effect   = "Allow"
        Action   = ["ec2:*", "s3:*", "iam:*", "airflow:*", "kms:*", "sns:*", "cloudwatch:*", "logs:*", "secretsmanager:*"]
        Resource = "*"
        # NOTE: broad by design for this reference project so `terraform apply`
        # works out of the box. Tighten to exact ARNs / add permission
        # boundaries before using this role against a real production account.
      },
    ]
  })
}
