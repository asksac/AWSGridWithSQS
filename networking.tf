data "aws_vpc" "selected_vpc" {
  id = var.ec2_vpc_id
}

# assuming the VPC is a /16 cidr block
resource "aws_subnet" "ec2_instance_subnet_1" {
  vpc_id                  = data.aws_vpc.selected_vpc.id
  availability_zone       = var.ec2_subnet_az_1
  cidr_block              = cidrsubnet(data.aws_vpc.selected_vpc.cidr_block, 2, 2) // creates a /18 subnet
  map_public_ip_on_launch = false
}

resource "aws_subnet" "ec2_instance_subnet_2" {
  vpc_id                  = data.aws_vpc.selected_vpc.id
  availability_zone       = var.ec2_subnet_az_2
  cidr_block              = cidrsubnet(data.aws_vpc.selected_vpc.cidr_block, 2, 3) // creates a /18 subnet
  map_public_ip_on_launch = false
}
