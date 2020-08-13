variable "ec2_vpc_id" {
  type          = string
  description   = "Specify the ID of an existing VPC with an internet gateway configured"
/*
  # validation requires Terraform CLI v0.13.0
  validation {
    condition     = length(var.ec2_vpc_id) > 4 && substr(var.ec2_vpc_id, 0, 4) == "vpc-"
    error_message = "The vpc id value must be valid, starting with \"vpc-\"."
  }
*/
}

variable "ec2_subnet_az_1" {
  type    = string
  default = "us-east-1a"
}

variable "ec2_subnet_az_2" {
  type    = string
  default = "us-east-1b"
}

variable "ec2_ssh_keypair_name" {
  type    = string
  description   = "Specify the name of an existing SSH keypair"
}

variable "aws_env" {
  type    = string
  description   = "Specify an AWS_ENV value, e.g. dev, test, uat, prod"
}
