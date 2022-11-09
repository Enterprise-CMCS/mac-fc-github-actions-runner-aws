data "aws_caller_identity" "current" {}

locals {
  create_provider = var.existing_iam_oidc_provider_arn == "" ? true : false
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count           = local.create_provider ? 1 : 0
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
      identifiers = [local.create_provider? aws_iam_openid_connect_provider.github_actions[0].arn : var.existing_iam_oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "github_actions_oidc" {
  name               = "github-actions-oidc"
  description        = "A service role for use with GitHub Actions OIDC"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  # path and permssions boundary as required per https://cloud.cms.gov/creating-identity-access-management-policies
  path                 = "/delegatedadmin/developer/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"
  managed_policy_arns  = var.add_read_only_access ? ["arn:aws:iam::aws:policy/ReadOnlyAccess"] : [""]
}

resource "aws_iam_role_policy" "github_actions_permissions" {
  name   = "github-actions-permissions"
  role   = aws_iam_role.github_actions_oidc.id
  policy = file("${path.root}/${var.github_actions_permissions_policy_json_path}")
}
