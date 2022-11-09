variable "subject_claim_filters" {
  description = "A list of valid subject claim filters" # see https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-subject-claims for examples of filtering by branch or environment
  type        = list(string)
}

variable "audience_list" {
  description = "A list of allowed audiences (AKA client IDs) for the AWS identity provider"
  type        = list(string)
  default     = ["sts.amazonaws.com"] # the default audience for the GitHub OIDC provider, see https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services#adding-the-identity-provider-to-aws
}

variable "thumbprint_list" {
  description = " A list of thumbprints for the OIDC identity provider's server certificate"
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # see https://github.blog/changelog/2022-01-13-github-actions-update-on-oidc-based-deployments-to-aws/ and https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
}

variable "github_actions_permissions_policy_json_path" {
  description = "Path to a JSON document describing IAM permissions for GitHub Actions relative to the module root"
  type        = string
  default     = "github_actions_permission_policy.json"
}

variable "add_read_only_access" {
  description = "Add the AWS read-only managed policy to the OIDC role"
  type        = bool
  default     = false
}

variable "create_iam_oidc_provider" {
  description = "Create the IAM OIDC provider"
  type        = bool
  default     = true
}

