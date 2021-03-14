# Create IAM policy document allowing Lambda service to assume the role
data "aws_iam_policy_document" "lambda_assume_role" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

# Create role the Lambda function will assume
resource "aws_iam_role" "lambda" {
  name = "${local.lambda_name_snake}Lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Create policy allowing Lambda access to required resources
data "aws_iam_policy_document" "lambda_application_policy" {
  version = "2012-10-17"
  statement {
    sid = "VpcNetworkInterfaceAccess"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    sid = "CloudWatchLogGroupAccess"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "cloudwatch:PutMetricData"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
}

# Attach application policy to the Lambda functions IAM role
resource "aws_iam_role_policy" "lambda_application_policy" {
  name = "${local.lambda_name_snake}Lambda"
  role = aws_iam_role.lambda.name
  policy = data.aws_iam_policy_document.lambda_application_policy.json
}