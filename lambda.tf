locals {
  # Calculate values for internal use
  lambda_name_snake     = join("", [for element in split("-", lower(replace(var.lambda_name, "_", "-"))) : title(element)])
  lambda_runtime        = "python${var.lambda_python_version}"
  lambda_delta_filename = "${path.module}/lambda-${var.lambda_name}-delta.zip"
  lambda_build_path     = "${path.module}/lambda-${var.lambda_name}-build"
  lambda_filename       = "${path.module}/lambda-${var.lambda_name}.zip"
}

# Retrieve the AWS region and caller identity to which we are deploying this function
data "aws_region" "default" {}
data "aws_caller_identity" "default" {}


# Archive the folder containing the Lambda functions source code
data "archive_file" "lambda_delta" {
  type        = "zip"
  source_dir  = "${var.lambda_path}/"
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
      echo "Creating build path: ${local.lambda_build_path}/"
      mkdir -p ${local.lambda_build_path}/ || exit 1;
      echo "Copying: ${var.lambda_path}/. -> ${local.lambda_build_path}/"
      cp -a ${var.lambda_path}/. ${local.lambda_build_path}/;
      echo "Installing Python dependencies"
      python3 -m pip install --upgrade pip;
      touch ${local.lambda_build_path}/requirements.txt;
      pip3 install -r ${local.lambda_build_path}/requirements.txt -t ${local.lambda_build_path};
      cd ${local.lambda_build_path};
      echo "Compressing: ${local.lambda_filename}"
      zip -r ${local.lambda_filename} .;
      ls -l ${local.lambda_build_path};
    COMMAND
  }
}

# Lambda function
resource "aws_lambda_function" "lambda" {
  depends_on = [
    null_resource.lambda_build
  ]
  function_name = local.lambda_name_snake
  description   = var.lambda_description
  filename      = local.lambda_filename
  role          = aws_iam_role.lambda.arn
  handler       = var.lambda_handler
  runtime       = local.lambda_runtime
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout
  environment {
    variables = merge({
      LAMBDA_FUNCTION_NAME = var.lambda_name,
      LAMBDA_IAM_ROLE_ARN  = aws_iam_role.lambda.arn,
      LAMBDA_MEMORY_SIZE   = var.lambda_memory,
      LAMBDA_RUNTIME       = local.lambda_runtime,
      LAMBDA_TIMEOUT       = var.lambda_timeout
    }, var.lambda_environment_variables)
  }
  dynamic "vpc_config" {
    for_each = var.lambda_subnet_ids == null ? {} : {
      subnet_ids         = var.lambda_subnet_ids
      security_group_ids = var.lambda_security_group_ids
    }
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
}
