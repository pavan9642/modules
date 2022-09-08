provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "custom_vpc" {
  cidr_block       = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_tag_name}-${var.environment}"
  }
}

### VPC Network Setup

# Create the private subnets
resource "aws_subnet" "private_subnet" {
  count = var.number_of_private_subnets
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.private_subnet_tag_name}-${var.environment}"
  }
}

# Create the public subnets
resource "aws_subnet" "app_public_subnet" {
  count = var.number_of_public_subnets
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.public_subnet_tag_name}-${var.environment}"
  }
}

### Security Group Setups

# ALB Security group
resource "aws_security_group" "lb" {
  name        = "${var.security_group_lb_name}-${var.environment}"
  description = var.security_group_lb_description
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
# or AWS services through an AWS PrivateLink
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.security_group_ecs_tasks_name}-${var.environment}"
  description = var.security_group_ecs_tasks_description
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [
      aws_vpc_endpoint.s3.prefix_list_id
    ]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "app_elastic_ip" {
  count = var.number_of_public_subnets
  vpc = true
  tags = {
    Name = "${var.app_name}_elastic_ip-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "app_internet_gateway" {
  vpc_id = aws_vpc.custom_vpc.id
}

resource "aws_nat_gateway" "app_nat_gateway" {
  allocation_id = aws_eip.app_elastic_ip[count.index].id
  count = var.number_of_public_subnets
  subnet_id = aws_subnet.app_public_subnet[count.index].id
  tags = {
    Name = "${var.app_name}_nat_gateway"
  }
}

resource "aws_route_table" "app_private_route_table" {
  vpc_id = aws_vpc.custom_vpc.id
  count = var.number_of_private_subnets
  tags = {
    Name = "${aws_subnet.private_subnet[count.index].availability_zone}-route-table-NAT"
  }
}

resource "aws_route_table" "app_public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id
  count = var.number_of_public_subnets
  tags = {
    Name = "${aws_subnet.app_public_subnet[count.index].availability_zone}-route-table-public"
  }
}

resource "aws_route_table_association" "app_nat_private_subnet_assoc" {
  count = var.number_of_private_subnets
  route_table_id = aws_route_table.app_private_route_table[count.index].id
  subnet_id = aws_subnet.private_subnet[count.index].id
}

resource "aws_route_table_association" "app_public_subnet_assoc" {
  count = var.number_of_public_subnets
  route_table_id = aws_route_table.app_public_route_table[count.index].id
  subnet_id = aws_subnet.app_public_subnet[count.index].id
}

resource "aws_route" "app_ig_public_subnet_route" {
  count = var.number_of_public_subnets
  route_table_id = aws_route_table.app_public_route_table[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.app_internet_gateway.id
}

resource "aws_route" "app_nat_private_subnet_route" {
  count = var.number_of_private_subnets
  route_table_id = aws_route_table.app_private_route_table[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.app_nat_gateway[count.index].id
}
