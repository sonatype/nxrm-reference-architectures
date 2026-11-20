#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# Find which AZs support the requested instance type (e.g., m7g.xlarge may not be in all AZs)
data "aws_ec2_instance_type_offerings" "available" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }

  location_type = "availability-zone"
}

# Look up existing VPC details when using BYOV (bring your own VPC)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

locals {
  # AZs that are both available AND support the requested instance type
  supported_azs = tolist(setintersection(
    toset(data.aws_availability_zones.available.names),
    toset(data.aws_ec2_instance_type_offerings.available.locations)
  ))
  azs = slice(local.supported_azs, 0, min(2, length(local.supported_azs)))

  vpc_id     = var.create_vpc ? aws_vpc.main[0].id : var.vpc_id
  vpc_cidr   = var.create_vpc ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block
  subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.subnet_ids

  # When using existing VPC, auto-detect CIDR; when creating new VPC, use configured CIDR
  effective_vpc_cidr = var.create_vpc ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block

  # Public subnets: created subnets when new VPC, customer-provided when BYOV
  public_subnet_ids = var.create_vpc ? aws_subnet.public[*].id : var.public_subnet_ids
}

# -----------------------------------------------------------------------------
# VPC (optional - created when create_vpc = true)
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# -----------------------------------------------------------------------------
# Subnets (2 AZs for HA)
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.create_vpc ? 2 : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = var.create_vpc ? 2 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway (for private subnet internet access)
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.create_vpc ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.create_vpc ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.create_vpc ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

resource "aws_security_group" "nxrm" {
  name_prefix = "${var.name_prefix}-nxrm-"
  description = "Security group for NXRM instances"
  vpc_id      = local.vpc_id

  # NXRM HTTP (from VPC CIDR only - ALB forwards to this port)
  ingress {
    description = "NXRM HTTP from VPC"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [local.effective_vpc_cidr]
  }

  # SSH access (from VPC CIDR only - use bastion/VPN for external access)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.effective_vpc_cidr]
  }

  # Hazelcast cluster communication (RA-3+)
  dynamic "ingress" {
    for_each = var.cluster_size > 1 ? [1] : []
    content {
      description = "Hazelcast clustering"
      from_port   = 5701
      to_port     = 5801
      protocol    = "tcp"
      self        = true
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-nxrm-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}


# NOTE: ALB security group is created by modules/loadbalancer to keep
# module ownership clear. The loadbalancer module manages its own SG
# with configurable ingress_cidr_blocks and aws_security_group_rule resources.


# NOTE: Database security group is created by modules/database to keep
# module ownership clear. The database module accepts allowed_security_group_ids
# as input and creates its own SG with aws_security_group_rule resources.
