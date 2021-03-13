variable "lambda_name" {
  type = string
}

variable "lambda_description" {
  type = string
}

variable "lambda_path" {
  type = string
}

variable "lambda_handler" {
  type = string
}

variable "lambda_python_version" {
  type = string
}

variable "lambda_memory" {
  type = number
}

variable "lambda_timeout" {
  type = number
}

variable "lambda_cloudwatch_encryption_enabled" {
  type = bool
  default = true
}

variable "lambda_cloudwatch_retention_in_days" {
  type = number
  default = 0
}

variable "lambda_subnet_ids" {
  type = set(string)
}

variable "lambda_security_group_ids" {
  type = set(string)
}

variable "lambda_environment_variables" {
  type = map(string)
  default = {}
}

variable "load_balancer_enabled" {
  type = bool
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
  default = false
}

variable "load_balancer_domain_name" {
  type = string
  default = null
}

variable "load_balancer_domain_name_hosted_zone_id" {
  type = string
  default = null
}

variable "load_balancer_health_check_enabled" {
  type = bool
  default = false
}

variable "load_balancer_health_check_interval" {
  type = number
  default = 60
}

variable "load_balancer_health_check_url" {
  type = string
}

variable "load_balancer_https_enabled" {
  type = bool
  default = false
}

variable "load_balancer_https_ssl_policy" {
  type = string
  default = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
}

variable "load_balancer_https_certificate_arn" {
  type = string
  default = null
}

variable "load_balancer_subnet_ids" {
  type = set(string)
  default = []
}

variable "load_balancer_security_group_ids" {
  type = set(string)
  default = []
}
