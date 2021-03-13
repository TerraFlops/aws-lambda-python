locals {
  # Calculate values for internal use
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
  lambda_name_snake = join("", [for element in split("-", lower(replace(var.lambda_name, "_", "-"))) : title(element)])
  lambda_cloudwatch_log_group_name = "/aws/lambda/${local.lambda_name_snake}"
  lambda_build_path = "/tmp/lambda-build-${var.lambda_name}/${local.timestamp}"
  lambda_filename = "/tmp/lambda-${var.lambda_name}.zip"
  lambda_delta_filename = "/tmp/lambda-delta-${var.lambda_name}.zip"
  lambda_hash_filename = "/tmp/lambda-hash-${var.lambda_name}.txt"
  lambda_runtime = "python${var.lambda_python_version}"
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
  # Trigger the build based on the hash of the Lambda functions source code to prevent unnecessary redeploys
  triggers = {
    source_hash = filesha512(data.archive_file.lambda_delta.output_path)
  }
  provisioner "local-exec" {
    # Build the Lambda function
    command = <<-COMMAND
      mkdir -p ${local.lambda_build_path}/;
      cp -a ${var.lambda_path}/. ${local.lambda_build_path}/;
      python3 -m pip install --upgrade pip;
      touch ${local.lambda_build_path}/requirements.txt;
      pip3 install -r ${local.lambda_build_path}/requirements.txt -t ${local.lambda_build_path};
      cd ${local.lambda_build_path};
      zip -r ${local.lambda_filename} ${local.lambda_build_path};
    COMMAND
  }
}

# Lambda function
resource "aws_lambda_function" "lambda" {
  depends_on = [
    null_resource.lambda_build
  ]
  function_name = local.lambda_name_snake
  description = var.lambda_description
  filename = local.lambda_filename
  source_code_hash = fileexists(local.lambda_filename) == true ? filebase64sha256(data.archive_file.lambda_delta.output_path) : null
  role = aws_iam_role.lambda.arn
  handler = var.lambda_handler
  runtime = local.lambda_runtime
  memory_size = var.lambda_memory
  timeout = var.lambda_timeout
  vpc_config {
    subnet_ids = var.lambda_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }
}
