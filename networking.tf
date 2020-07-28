data "aws_vpc" "selected_vpc" {
  id = var.ec2_vpc_id
}

resource "aws_subnet" "ec2_instance_subnet" {
  vpc_id                  = data.aws_vpc.selected_vpc.id
  availability_zone       = var.ec2_subnet_az
  cidr_block              = cidrsubnet(data.aws_vpc.selected_vpc.cidr_block, 8, 96)
  map_public_ip_on_launch = true
}
