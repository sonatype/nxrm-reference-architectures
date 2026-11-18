#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# modules/loadbalancer/main.tf - ALB with HTTPS for NXRM
# Provides HTTPS termination and load balancing across NXRM instances

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "alb" {
  name_prefix = "${var.environment_name}-nxrm-alb-"
  description = "Security group for NXRM Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from allowed CIDR blocks"
}

resource "aws_security_group_rule" "alb_https_ingress" {
  count = var.certificate_arn != "" ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from allowed CIDR blocks"
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic to reach targets"
}

###############################################################################
# Application Load Balancer
###############################################################################

resource "aws_lb" "this" {
  name_prefix        = "nxrm-"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true

  idle_timeout = var.idle_timeout

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-alb"
  })
}

###############################################################################
# Target Group
###############################################################################

resource "aws_lb_target_group" "nxrm" {
  name_prefix = "nxrm-"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = tostring(var.target_port)
    protocol            = "HTTP"
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = "200"
  }

  deregistration_delay = var.deregistration_delay

  stickiness {
    type            = "lb_cookie"
    enabled         = var.enable_stickiness
    cookie_duration = var.stickiness_duration
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# Listeners
###############################################################################

# HTTP listener - redirects to HTTPS if certificate provided, otherwise forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn == "" ? aws_lb_target_group.nxrm.arn : null
  }
}

# HTTPS listener - terminates TLS and forwards to NXRM target group (only when certificate provided)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nxrm.arn
  }
}
