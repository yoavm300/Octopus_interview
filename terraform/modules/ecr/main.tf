resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  # provision-aws.sh always pushes an image here, so without force_delete
  # every teardown-aws.sh run fails with "RepositoryNotEmptyException" --
  # found live when a destroy halted on exactly this after a real deploy.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}
