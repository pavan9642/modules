output vpc_arn {
  value = aws_vpc.custom_vpc.arn
}

output vpc_id {
  value = aws_vpc.custom_vpc.id
}

output private_subnet_ids {
  value = aws_subnet.private_subnet.*.id
}

output ecs_tasks_security_group_id {
  value = aws_security_group.ecs_tasks.id
}

output main_pvt_route_table_id {
  value = aws_vpc.custom_vpc.main_route_table_id
}

output "vpc_tag_name" {
  value = aws_vpc.custom_vpc.tags.Name
}

output "vpc_cidr_block" {
  value = aws_vpc.custom_vpc.cidr_block
}
