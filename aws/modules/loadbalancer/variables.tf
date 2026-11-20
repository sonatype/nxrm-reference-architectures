#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "environment_name" {
  description = "Name prefix for all load balancer resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs for the ALB (minimum 2 in different AZs)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs in different availability zones are required for the ALB."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener. If empty, uses HTTP only."
  type        = string
  default     = ""
}

variable "internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "target_port" {
  description = "Port on which NXRM instances listen"
  type        = number
  default     = 8081
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/service/rest/v1/status"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before marking healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking unhealthy"
  type        = number
  default     = 3
}

variable "deregistration_delay" {
  description = "Time in seconds before deregistering a target (allows in-flight requests to complete)"
  type        = number
  default     = 30
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 120
}

variable "enable_stickiness" {
  description = "Enable session stickiness on the target group"
  type        = bool
  default     = true
}

variable "stickiness_duration" {
  description = "Duration in seconds for session stickiness cookie"
  type        = number
  default     = 86400
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB on ports 80 and 443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB to prevent accidental destruction"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all load balancer resources"
  type        = map(string)
  default     = {}
}
