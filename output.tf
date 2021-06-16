output "lambda_function_arn" {
  value = var.ignore_changes == true ? aws_lambda_function.lambda_ignored[0].arn : aws_lambda_function.lambda_updated[0].arn
}

output "lambda_function_name" {
  value = var.ignore_changes == true ? aws_lambda_function.lambda_ignored[0].function_name : aws_lambda_function.lambda_updated[0].function_name
}

output "lambda_function_version" {
  value = var.ignore_changes == true ? aws_lambda_function.lambda_ignored[0].version : aws_lambda_function.lambda_updated[0].version
}

output "load_balancer_arn" {
  value = var.load_balancer_enabled == true ? aws_lb.load_balancer[0].arn : null
}

output "cloudwatch_kms_key_arn" {
  value = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_key.lambda_cloudwatch[0].arn : null
}

output "cloudwatch_kms_key_id" {
  value = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_key.lambda_cloudwatch[0].key_id : null
}

output "cloudwatch_kms_alias_arn" {
  value = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_alias.lambda_cloudwatch[0].arn : null
}

output "cloudwatch_kms_alias_name" {
  value = var.lambda_cloudwatch_encryption_enabled == true ? aws_kms_alias.lambda_cloudwatch[0].name : null
}
