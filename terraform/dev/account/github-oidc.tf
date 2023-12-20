data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  client_id_list  = var.audience_list
  thumbprint_list = var.thumbprint_list
  url             = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "RoleForGitHubActions"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = var.audience_list
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.subject_claim_filters
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
  }
}

resource "aws_iam_role" "github_actions_oidc" {
  name                 = "github-actions-oidc"
  description          = "A service role for use with GitHub Actions OIDC"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  path                 = "/delegatedadmin/developer/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:TagResource"
    ]
    resources = ["arn:aws:ecr:us-east-1:037370603820:repository/github-actions-runner"]
  }
}

resource "aws_iam_role_policy" "github_actions_permissions" {
  name   = "github-actions-permissions"
  role   = aws_iam_role.github_actions_oidc.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
