resource "aws_lambda_permission" "lambda" {
  count = var.load_balancer_enabled == true ? 1 : 0
  statement_id = "LoadBalancerInvokeAccess"
  function_name = aws_lambda_function.lambda.function_name
  action = "lambda:InvokeFunction"
  principal = "elasticloadbalancing.amazonaws.com"
}

resource "aws_lb" "load_balancer" {
  count = var.load_balancer_enabled == true ? 1 : 0
  name = local.lambda_name_snake
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
  count = var.load_balancer_enabled == true ? 1 : 0
  load_balancer_arn = aws_lb.load_balancer[0].arn
  port = var.load_balancer_port_public
  protocol = var.load_balancer_https_enabled == true ? "HTTPS" : "HTTP"
  ssl_policy = var.load_balancer_https_enabled == true ? var.load_balancer_https_ssl_policy : null
  certificate_arn = var.load_balancer_https_enabled == true ? var.load_balancer_https_certificate_arn : null
  # Setup default action
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "The requested resource could not be found"
      status_code = "404"
    }
  }
}

# Create target group to forward requests to
resource "aws_lb_target_group" "load_balancer" {
  depends_on = [
    aws_lambda_permission.lambda
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
}

# Attach the target group the load balancer
resource "aws_lb_target_group_attachment" "load_balancer" {
  count = var.load_balancer_enabled == true ? 1 : 0
  target_group_arn = aws_lb_target_group.load_balancer[0].arn
  target_id = aws_lambda_function.lambda.arn
}

# Create load balancer listener rule
resource "aws_lb_listener_rule" "load_balancer" {
  count = var.load_balancer_enabled == true ? 1 : 0
  listener_arn = aws_lb_listener.load_balancer[0].arn
  priority = 100
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.load_balancer[0].arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
