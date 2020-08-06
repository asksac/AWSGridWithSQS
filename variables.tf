variable "ec2_vpc_id" {
  type    = string
  default = "vpc-7eb0f404"
}

variable "ec2_subnet_az" {
  type    = string
  default = "us-east-1a"
}

variable "ec2_ssh_keypair_name" {
  type    = string
  default = "ssh_keypair_project_vedas"
}
