output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "tfstate_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "tfstate_lock_table" {
  value = aws_dynamodb_table.tf_locks.name
}
