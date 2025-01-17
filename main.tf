data "aws_kms_key" "repo" {
  key_id = var.kms_key
}

resource "aws_ecr_repository" "repo" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  encryption_configuration {
    encryption_type = var.kms_key == null ? "AES256" : "KMS"
    kms_key         = data.aws_kms_key.repo.arn
  }

  image_scanning_configuration {
    scan_on_push = var.scan_image_on_push
  }

  tags = var.tags
}

resource "aws_ecr_repository_policy" "repo" {
  count      = min(length(var.external_principals), 1)
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow other accounts belonging to the organisation to pull the image",
      "Effect": "Allow",
      "Principal": ${var.external_principals},
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetAuthorizationToken"
      ]
    }
  ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "days" {
  count      = min(var.delete_after_days, 1)
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire images older than ${var.delete_after_days} days",
      "selection": {
        "tagStatus": "any",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": ${var.delete_after_days}
      },
      "action": {
          "type": "expire"
      }
    }
  ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "count" {
  count      = min(var.delete_after_count, 1)
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last ${var.delete_after_count} images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": ${var.delete_after_count}
      },
      "action": {
          "type": "expire"
      }
    }
  ]
}
EOF
}
