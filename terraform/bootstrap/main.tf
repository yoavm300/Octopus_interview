# One-time bootstrap: the GitHub Actions OIDC provider and the role the
# deploy-aws.yml workflow assumes. This can't be created by the workflow
# itself (it needs the role to exist before it can assume anything), so it's
# applied once, manually, with real AWS credentials -- not by CI.

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
    ]
  })
}
