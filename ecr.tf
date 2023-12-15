terraform {
  required_version = "= 1.5.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.30.0"
    }
  }
}

provider "aws" {
  allowed_account_ids = ["037370603820"]

}

data "aws_organizations_organization" "cmsgov" {}

resource "aws_ecr_repository" "github_actions_runner" {
  name = "github-actions-runner"

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "github_actions_runner" {
  repository = aws_ecr_repository.github_actions_runner.name
  policy     = <<EOF
{
  "rules": [
    {
      "action": {
        "type": "expire"
      },
      "description": "Keep last 500 images",
      "rulePriority": 10,
      "selection": {
        "countNumber": 500,
        "countType": "imageCountMoreThan",
        "tagStatus": "any"
      }
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "ecr_perms_ro_organization" {

  statement {
    sid = "OrganizationECRReadOnly"

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
      type        = "AWS"
      identifiers = ["*"]
    }

    # give read only to principals (e.g., IAM Roles) in the current AWS organization
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalOrgID"
      values   = [data.aws_organizations_organization.cmsgov.id]
    }
  }
}

resource "aws_ecr_repository_policy" "github_actions_runner" {
  repository = aws_ecr_repository.github_actions_runner.name
  policy     = data.aws_iam_policy_document.ecr_perms_ro_organization.json
}
