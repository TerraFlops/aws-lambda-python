variable "lambda_name" {
  type = string
  description = "Lambda function name"
}

variable "lambda_description" {
  type = string
  description = "Lambda function description"
}

variable "lambda_handler" {
  type = string
  description = "Lambda function handler (will default to placeholder function entrypoint)"
  default = "handler.handler"
}

variable "lambda_python_version" {
  type = string
  description = "Python interpreter version (defaults to 3.8)"
  default = "3.8"
}

variable "lambda_memory" {
  type = number
  description = "Lambda function memory (defaults to 128MB)"
  default = "128"
}

variable "lambda_timeout" {
  type = number
  description = "Lambda function timeout (defaults to 30 seconds)"
  default = "30"
}

variable "lambda_cloudwatch_encryption_enabled" {
  type = bool
  description = "If true, CloudWatch logs will be encrypted with a KMS key"
  default = true
}

variable "lambda_cloudwatch_retention_in_days" {
  type = number
  description = "Number of days CloudWatch logs should be retained (defaults to 3653 days)"
  default = 3653
}

variable "lambda_subnet_ids" {
  type = set(string)
  description = "Optional set of subnet IDs (if the Lambda is joined to a VPC)"
  default = []
}

variable "lambda_iam_role_arn" {
  type = string
  description = "Lambda function execution IAM role ARN"
}

variable "lambda_security_group_ids" {
  type = set(string)
  description = "Optional set of security group IDs (if the Lambda is joined to a VPC)"
  default = []
}

variable "lambda_environment_variables" {
  type = map(string)
  description = "Lambda function environment variables"
  default = {}
}

variable "load_balancer_enabled" {
  type = bool
  description = "If true, a load balancer will be provisioned for HTTPS access to the lambda function"
  default = false
}

variable "load_balancer_port_public" {
  type = number
  default = 443
}

variable "load_balancer_port_lambda" {
  type = number
  default = 5000
}

variable "load_balancer_domain_name_enabled" {
  type = bool
  description = "If true a domain name will be provisioned pointing to the load balancer"
  default = false
}

variable "load_balancer_domain_name" {
  type = string
  description = "Domain name for function if load balancer is enabled"
  default = null
}

variable "load_balancer_domain_name_hosted_zone_id" {
  type = string
  description = "Hosted zone ID for load balancer CNAME"
  default = null
}

variable "load_balancer_health_check_enabled" {
  type = bool
  description = "If true health check will be enabled on the Lambda function"
  default = false
}

variable "load_balancer_health_check_interval" {
  type = number
  description = "Load balancer health check interval"
  default = 60
}

variable "load_balancer_health_check_url" {
  type = string
  default = "/ping"
}

variable "load_balancer_https_enabled" {
  type = bool
  description = "If true, load balancer will be configured with HTTPS"
  default = false
}

variable "load_balancer_https_ssl_policy" {
  type = string
  default = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
}

variable "load_balancer_https_certificate_arn" {
  type = string
  description = "Load balancer certificate ARN"
  default = null
}

variable "load_balancer_subnet_ids" {
  type = set(string)
  description = "List of subnet IDs in which the load balancer should be provisioned"
  default = []
}

variable "load_balancer_security_group_ids" {
  type = set(string)
  description = "List of security group IDs which will be attached to the load balancer"
  default = []
}

variable "load_balancer_path_patterns" {
  type = list(string)
  default = null
}
