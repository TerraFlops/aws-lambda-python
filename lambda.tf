locals {
  # Calculate values for internal use
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
  lambda_name_camel = join("", [for element in split("-", lower(replace(var.lambda_name, "_", "-"))) : title(element)])
  lambda_runtime = "python${var.lambda_python_version}"
  lambda_delta_filename = "/tmp/lambda-${var.lambda_name}-delta-${local.timestamp}.zip"
  lambda_output_path = "/tmp/lambda-${var.lambda_name}-output"
}

# Retrieve the AWS region and caller identity to which we are deploying this function
data "aws_region" "default" {}
data "aws_caller_identity" "default" {}


# Archive the folder containing the Lambda functions source code
data "archive_file" "lambda_delta" {
  type = "zip"
  source_dir = "${var.lambda_path}/"
  output_path = local.lambda_delta_filename
}

# Pull down the Lambda functions dependencies to create ZIP file
resource "null_resource" "lambda_build" {
  depends_on = [
    data.archive_file.lambda_delta
  ]
  # Trigger the build based on the hash of the Lambda functions source code to prevent unnecessary redeploys
  triggers = {
    source_hash = filesha512(data.archive_file.lambda_delta.output_path)
  }
  provisioner "local-exec" {
    # Build the Lambda function
    command = <<-COMMAND
      apt o APT::Sandbox::User=root update;
      apt install -y -o APT::Sandbox::User=root docker;
      apt install -y -o APT::Sandbox::User=root --no-install-recommends apt-transport-https;
      apt install -y -o APT::Sandbox::User=root --no-install-recommends ca-certificates;
      apt install -y -o APT::Sandbox::User=root --no-install-recommends curl;
      apt install -y -o APT::Sandbox::User=root --no-install-recommends gnupg;
      apt install -y -o APT::Sandbox::User=root --no-install-recommends lsb-release;
      mkdir -p ${local.lambda_output_path};
      ls / -l;
      /usr/bin/docker run --rm \
        -v $(realpath ${var.lambda_path})/:/opt/src \
        -v ${local.lambda_output_path}/:/opt/output \
        eonxcom/lambda-build-python-${var.lambda_python_version}:latest \
        package_local "${local.timestamp}.zip";
      if [ ! -z "${var.lambda_s3_bucket == null ? "" : var.lambda_s3_bucket}" ]; then
        aws s3 cp ${local.lambda_output_path}/${local.timestamp}.zip s3://${var.lambda_s3_bucket == null ? "" : var.lambda_s3_bucket}/${local.timestamp}.zip \
          --acl bucket-owner-full-control \
          --sse AES256;
      fi;
    COMMAND
  }
}

# Lambda function
resource "aws_lambda_function" "lambda_ignored" {
  count = var.ignore_changes == true ? 1 : 0
  depends_on = [
    null_resource.lambda_build
  ]
  function_name = local.lambda_name_camel
  description = var.lambda_description
  filename = var.lambda_s3_bucket != null ? null : "${local.lambda_output_path}/${local.timestamp}.zip"
  s3_bucket = var.lambda_s3_bucket != null ? var.lambda_s3_bucket : null
  s3_key = var.lambda_s3_bucket != null ? "${local.timestamp}.zip" : null
  role = var.lambda_iam_role_arn
  handler = var.lambda_handler
  runtime = local.lambda_runtime
  memory_size = var.lambda_memory
  timeout = var.lambda_timeout
  environment {
    variables = merge({
      LAMBDA_FUNCTION_NAME = var.lambda_name,
      LAMBDA_IAM_ROLE_ARN = var.lambda_iam_role_arn,
      LAMBDA_MEMORY_SIZE = var.lambda_memory,
      LAMBDA_RUNTIME = local.lambda_runtime,
      LAMBDA_TIMEOUT = var.lambda_timeout
    }, var.lambda_environment_variables)
  }
  vpc_config {
    subnet_ids = tolist(sort(var.lambda_subnet_ids == null ? [] : var.lambda_subnet_ids))
    security_group_ids = tolist(sort(var.lambda_security_group_ids == null ? [] : var.lambda_security_group_ids))
  }
  lifecycle {
    ignore_changes = [
      filename,
      s3_bucket,
      s3_key,
      source_code_hash
    ]
  }
}

# Lambda function
resource "aws_lambda_function" "lambda_updated" {
  count = var.ignore_changes == false ? 1 : 0
  depends_on = [
    null_resource.lambda_build
  ]
  function_name = local.lambda_name_camel
  description = var.lambda_description
  filename = var.lambda_s3_bucket != null ? null : "${local.lambda_output_path}/${local.timestamp}.zip"
  s3_bucket = var.lambda_s3_bucket != null ? var.lambda_s3_bucket : null
  s3_key = var.lambda_s3_bucket != null ? "${local.timestamp}.zip" : null
  role = var.lambda_iam_role_arn
  handler = var.lambda_handler
  runtime = local.lambda_runtime
  memory_size = var.lambda_memory
  timeout = var.lambda_timeout
  environment {
    variables = merge({
      LAMBDA_FUNCTION_NAME = var.lambda_name,
      LAMBDA_IAM_ROLE_ARN = var.lambda_iam_role_arn,
      LAMBDA_MEMORY_SIZE = var.lambda_memory,
      LAMBDA_RUNTIME = local.lambda_runtime,
      LAMBDA_TIMEOUT = var.lambda_timeout
    }, var.lambda_environment_variables)
  }
  vpc_config {
    subnet_ids = tolist(sort(var.lambda_subnet_ids == null ? [] : var.lambda_subnet_ids))
    security_group_ids = tolist(sort(var.lambda_security_group_ids == null ? [] : var.lambda_security_group_ids))
  }
}

resource "aws_lambda_alias" "lambda" {
  depends_on = [
    aws_lambda_function.lambda_ignored,
    aws_lambda_function.lambda_updated
  ]
  name = var.lambda_name
  function_name = var.ignore_changes == true ? aws_lambda_function.lambda_ignored[0].arn : aws_lambda_function.lambda_updated[0].arn
  function_version = var.ignore_changes == true ? aws_lambda_function.lambda_ignored[0].version : aws_lambda_function.lambda_updated[0].version
}
