# One-time bootstrap: the GitHub Actions OIDC provider and the role the
# deploy-aws.yml workflow assumes, plus the S3 bucket + DynamoDB lock table
# the main terraform/ root module uses as its remote state backend. All of
# this has to exist before the workflow that depends on it can run (and the
# state backend can't manage its own state), so it's applied once, manually,
# with real AWS credentials -- not by CI.

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "deploy" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # GitHub embeds numeric owner/repo IDs in the sub claim (e.g.
          # "repo:owner@123/repo@456:ref:...") as an anti-spoofing measure, so
          # match on name prefixes rather than the exact "owner/repo" string.
          "token.actions.githubusercontent.com:sub" = "repo:${replace(var.github_repo, "/", "*/")}*:*"
        }
      }
    }]
  })
}

# Scoped to the AWS services this exercise's Terraform actually touches
# (ec2/eks/ecr/kms/logs/elb), rather than account-wide admin. Still broad
# within those services -- a real production role would scope further to
# specific resource ARNs/tags; disproportionate for this exercise.
#tfsec:ignore:aws-iam-no-policy-wildcards -- per-service wildcards are intentional here (see comment above); already scoped to specific services rather than "*:*".
resource "aws_iam_role_policy" "deploy" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Infra"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "ecr:*",
          "kms:*",
          "logs:*",
          "elasticloadbalancing:*",
          "sts:GetCallerIdentity",
        ]
        Resource = "*"
      },
      {
        Sid    = "IamForClusterAndControllerRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
        ]
        Resource = "*"
      },
      {
        Sid    = "TfStateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
        ]
      },
      {
        Sid    = "TfStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = aws_dynamodb_table.tf_locks.arn
      },
    ]
  })
}

# Remote state backend for terraform/, so a terraform apply and the
# teardown that must later undo it can run in different CI jobs (each on a
# fresh runner with no local state) and still see the same resources. A
# previous live test found this out the hard way: a failed apply left a
# real EKS cluster running, and the next job's "terraform destroy" had
# nothing to destroy because its local state was empty.
resource "random_id" "tfstate_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "apples-exercise-tfstate-${random_id.tfstate_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "apples-exercise-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
