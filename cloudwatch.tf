locals {
  # The CloudWatch log group name is dictated by AWS in the format `/aws/lambda/function`
  lambda_cloudwatch_log_group_name = "/aws/lambda/${local.lambda_name_snake}"
}

# Create CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda" {
  depends_on = [
    aws_kms_alias.lambda_cloudwatch
  ]
  name = local.lambda_cloudwatch_log_group_name
  retention_in_days = var.lambda_cloudwatch_retention_in_days
  kms_key_id = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_key.lambda_cloudwatch[0].arn : null
}

# Create KMS key for encrypting CloudWatch logs at rest
resource "aws_kms_key" "lambda_cloudwatch" {
  count = var.lambda_cloudwatch_encryption_enabled == true ? 1 : 0
  enable_key_rotation = true
  deletion_window_in_days = 30
  policy = data.aws_iam_policy_document.lambda_cloudwatch[0].json
}

# Create KMS key alias
resource "aws_kms_alias" "lambda_cloudwatch" {
  count = var.lambda_cloudwatch_encryption_enabled == true ? 1 : 0
  target_key_id = aws_kms_key.lambda_cloudwatch[0].key_id
  name = "alias/lambda/${lower(replace(replace(var.lambda_name, "_", ""), "-", ""))}"
}

# Create IAM policy granting the account access to the KMS key
data "aws_iam_policy_document" "lambda_cloudwatch" {
  count = var.lambda_cloudwatch_encryption_enabled == true ? 1 : 0
  version = "2012-10-17"
  statement {
    sid = "AccountRootFullAccess"
    effect = "Allow"
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.default.account_id}:root"]
      type = "AWS"
    }
    actions = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid = "CloudWatchKmsEncryptAccess"
    effect = "Allow"
    principals {
      identifiers = ["logs.${data.aws_region.default.name}.amazonaws.com"]
      type = "Service"
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
      test = "ArnEquals"
      values = ["arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:${local.lambda_cloudwatch_log_group_name}"]
      variable = "kms:EncryptionContext:aws:logs:arn"
    }
  }
}
