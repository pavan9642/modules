provider "aws" {
  region = "us-east-1"
  access_key  = "AKIA4AMDMQCSDTGUBBFW"
  secret_key = "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"
}
resource "aws_vpc" "custom_vpc" {
  cidr_block       = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_tag_name}-${var.environment}"
  }
}
