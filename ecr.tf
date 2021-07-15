locals {
  # Use our standard lifecycle policy if none passed in.
  policy = var.lifecycle_policy == "" ? file("${path.module}/ecr-lifecycle-policy.json") : var.lifecycle_policy

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_ecr_repository" "main" {
  name = var.container_name
  tags = merge(local.tags, var.tags)
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy     = local.policy
}

# attach a ECR policy to a repository and give read only cross account access to external principal accounts
resource "aws_ecr_repository_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy     = data.aws_iam_policy_document.ecr_perms_ro_cross_account.json
  count      = length(var.allowed_read_principals) > 0 ? 1 : 0
}

resource "aws_iam_policy" "main" {
  name        = "githubactions-ecr-${var.container_name}-policy"
  description = "Allow githubActions to push new inspec-profile-aws-mod ECR images"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = ""
        Action   = "ecr:GetAuthorizationToken"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid      = ""
        Action   = [
          "ecr:UploadLayerPart",
          "ecr:PutImage",
          "ecr:ListImages",
          "ecr:InitiateLayerUpload",
          "ecr:GetRepositoryPolicy",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Effect   = "Allow"
        Resource = aws_ecr_repository.main.arn
      }
    ]
  })
}

data "aws_iam_policy_document" "ecr_perms_ro_cross_account" {

  statement {
    sid = "CrossAccountReadOnly"

    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
    ]

    principals {
      identifiers = var.allowed_read_principals
      type        = "AWS"
    }
  }
}
