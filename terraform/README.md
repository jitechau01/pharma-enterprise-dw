# Terraform

```
terraform/
├── modules/
│   ├── s3/           reusable hardened bucket (versioning, SSE-KMS, deny-unencrypted-put policy)
│   ├── vpc/           MWAA-ready VPC (2 public + 2 private subnets, NAT, security group)
│   ├── iam/           MWAA execution role, GitHub OIDC role, Snowflake<->S3 trust role
│   ├── mwaa/           aws_mwaa_environment + SNS failure topic + CloudWatch alarm
│   └── snowflake/      databases/schemas, warehouses + resource monitor, RBAC roles/grants, storage integration/stage
└── environments/
    ├── dev/            fully wired root module (copy terraform.tfvars.example -> terraform.tfvars)
    ├── staging/         same composition, separate state/tfvars
    └── prod/             same composition, separate state/tfvars (force_destroy disabled)
```

## Two-step apply (Snowflake <-> S3 trust)

Snowflake's `STORAGE INTEGRATION` generates an AWS IAM user ARN + external ID
*after* it's created; the AWS IAM role's trust policy needs those values to
scope who can assume it. That's a circular dependency across two providers,
so this project applies in two passes:

```bash
cd terraform/environments/dev
terraform init
terraform apply                     # pass 1: creates everything, IAM role trust is temporarily account-root-scoped

terraform output snowflake_storage_integration_iam_user_arn
terraform output snowflake_storage_integration_external_id
# put both values into terraform.tfvars

terraform apply                     # pass 2: tightens the IAM role trust policy to the real Snowflake principal
```

## Validating without applying

This reference project was built without live AWS/Snowflake credentials or
network access to the Terraform provider registry, so `terraform
validate`/`plan` could not be run in the build environment. Every `.tf` file
was hand-reviewed for structural correctness (brace balance, resource/module
argument names against the AWS provider v5.x and Snowflake provider v0.9x
schemas). Before your first real apply, run:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

## Remote state bootstrap

`backend.tf` in each environment points at an S3 bucket + DynamoDB lock
table that must exist before `terraform init` will work. Create them once,
by hand or via a tiny separate Terraform config, per environment:

```bash
aws s3api create-bucket --bucket pharma-dw-tfstate-dev --region us-east-1
aws s3api put-bucket-versioning --bucket pharma-dw-tfstate-dev --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name pharma-dw-tfstate-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Notes / things to tighten before real production use

- `modules/iam/github_oidc.tf`'s `aws_iam_role_policy.github_actions` is
  intentionally broad (`ec2:*`, `s3:*`, etc.) so this reference project's CI
  applies cleanly out of the box. Scope it to exact resource ARNs (or add a
  permission boundary) before pointing it at a real production AWS account.
- `webserver_access_mode` defaults to `PUBLIC_ONLY` for the reference deploy
  (no VPN/Direct Connect assumed). Switch to `PRIVATE_ONLY` for a real prod
  environment and access the MWAA UI over VPN/Direct Connect/SSO proxy.
- Snowflake warehouse/role names are suffixed by environment
  (`_DEV`/`_STAGING`/`_PROD`) rather than using separate Snowflake accounts
  per environment. Many enterprises instead use one Snowflake account per
  environment; both are valid, the tradeoffs are noted in
  `docs/ARCHITECTURE.md`.
