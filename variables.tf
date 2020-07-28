variable "ec2_ami_id" {
  type    = string
  default = "ami-09d95fab7fff3776c"
}

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
