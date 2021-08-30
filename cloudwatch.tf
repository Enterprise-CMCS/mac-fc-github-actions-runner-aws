resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.environment}/github-runner"
  retention_in_days = var.cloudwatch_log_retention

  kms_key_id = aws_kms_key.log_enc_key.arn

  tags = {
    Name        = "github-runner"
    Environment = var.environment
    Automation  = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }

}

resource "aws_kms_key" "log_enc_key" {
  description         = "KMS key for encrypting logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cloudwatch_logs_allow_kms.json

  tags = {
    Automation = "Terraform"
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_allow_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow logs KMS access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        aws_cloudwatch_log_group.main.arn,
      ]
    }
  }
}
