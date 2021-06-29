data "aws_region" "default" {}
data "aws_caller_identity" "default" {}

locals {
  lambda_name_camel = join("", [for element in split("-", lower(replace(var.lambda_name, "_", "-"))) : title(element)])
  lambda_runtime = "python${var.lambda_python_version}"
}

resource "aws_lambda_function" "lambda" {
  function_name = local.lambda_name_camel
  description = var.lambda_description
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

resource "aws_lambda_alias" "lambda" {
  depends_on = [
    aws_lambda_function.lambda,
  ]
  name = var.lambda_name
  function_name = aws_lambda_function.lambda.arn
  function_version = aws_lambda_function.lambda.version
}

resource "aws_lambda_permission" "load_balancer" {
  depends_on = [
    aws_lambda_function.lambda,
    aws_lambda_alias.lambda
  ]
  count = var.load_balancer_enabled == false ? 0 : 1
  statement_id = "AllowExecutionFromLoadBalancer"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal = "elasticloadbalancing.amazonaws.com"
  qualifier = aws_lambda_alias.lambda.name
}

resource "aws_lb" "load_balancer" {
  depends_on = [
    aws_lambda_permission.load_balancer
  ]
  count = var.load_balancer_enabled == true ? 1 : 0
  name = local.lambda_name_camel
  internal = false
  load_balancer_type = "application"
  subnets = var.load_balancer_subnet_ids
  security_groups = var.load_balancer_security_group_ids
}

resource "aws_route53_record" "load_balancer" {
  count = var.load_balancer_enabled == true && var.load_balancer_domain_name_enabled == true ? 1 : 0
  zone_id = var.load_balancer_domain_name_hosted_zone_id
  name = var.load_balancer_domain_name
  type = "A"
  alias {
    name = aws_lb.load_balancer[0].dns_name
    zone_id = aws_lb.load_balancer[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_listener" "load_balancer" {
  depends_on = [
    aws_lambda_permission.load_balancer
  ]
  count = var.load_balancer_enabled == true ? 1 : 0
  load_balancer_arn = aws_lb.load_balancer[0].arn
  port = var.load_balancer_port_public
  protocol = var.load_balancer_https_enabled == true ? "HTTPS" : "HTTP"
  ssl_policy = var.load_balancer_https_enabled == true ? var.load_balancer_https_ssl_policy : null
  certificate_arn = var.load_balancer_https_enabled == true ? var.load_balancer_https_certificate_arn : null
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "The requested resource could not be found"
      status_code = "404"
    }
  }
}

resource "aws_lb_target_group" "load_balancer" {
  depends_on = [
    aws_lambda_permission.load_balancer
  ]
  count = var.load_balancer_enabled == true ? 1 : 0
  target_type = "lambda"
  name = aws_lambda_function.lambda.function_name
  port = var.load_balancer_port_lambda
  protocol = "HTTP"
  health_check {
    enabled = var.load_balancer_health_check_enabled
    port = var.load_balancer_enabled == true ? var.load_balancer_port_lambda : null
    path = var.load_balancer_enabled == true ? var.load_balancer_health_check_url : null
    interval = var.load_balancer_enabled == true ? var.load_balancer_health_check_interval : null
  }
  lambda_multi_value_headers_enabled = true
}

resource "aws_lb_target_group_attachment" "load_balancer" {
  depends_on = [
    aws_lambda_permission.load_balancer
  ]
  count = var.load_balancer_enabled == true ? 1 : 0
  target_group_arn = aws_lb_target_group.load_balancer[0].arn
  target_id = aws_lambda_alias.lambda.arn
}

resource "aws_lb_listener_rule" "load_balancer" {
  depends_on = [
    aws_lambda_permission.load_balancer
  ]
  count = var.load_balancer_enabled == true ? 1 : 0
  listener_arn = aws_lb_listener.load_balancer[0].arn
  priority = 100
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.load_balancer[0].arn
  }
  condition {
    path_pattern {
      values = var.load_balancer_path_patterns != null ? var.load_balancer_path_patterns : ["/*"]
    }
  }
}

locals {
  lambda_cloudwatch_log_group_name = "/aws/lambda/${local.lambda_name_camel}"
}

resource "aws_cloudwatch_log_group" "lambda" {
  depends_on = [
    aws_kms_alias.lambda_cloudwatch
  ]
  name = local.lambda_cloudwatch_log_group_name
  retention_in_days = var.lambda_cloudwatch_retention_in_days
  kms_key_id = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_key.lambda_cloudwatch[0].arn : null
}

resource "aws_kms_key" "lambda_cloudwatch" {
  count = var.lambda_cloudwatch_encryption_enabled == true ? 1 : 0
  enable_key_rotation = true
  deletion_window_in_days = 30
  policy = data.aws_iam_policy_document.lambda_cloudwatch[0].json
}

resource "aws_kms_alias" "lambda_cloudwatch" {
  count = var.lambda_cloudwatch_encryption_enabled == true ? 1 : 0
  target_key_id = aws_kms_key.lambda_cloudwatch[0].key_id
  name = "alias/lambda/${lower(replace(replace(var.lambda_name, "_", ""), "-", ""))}"
}

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
