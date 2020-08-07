data "aws_ami" "ec2_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name      = "name"
    values    = ["amzn2-ami-hvm-2*"]
  }

  filter {
    name      = "architecture"
    values    = ["x86_64"]
  }

  filter {
    name      = "root-device-type"
    values    = ["ebs"]
  }

  filter {
    name      = "virtualization-type"
    values    = ["hvm"]
  }
}

output "ec2_ami_arn" {
  value = data.aws_ami.ec2_ami.arn
}