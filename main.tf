provider "aws" {
  profile = "terraform"
  region = "us-east-1"
}

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

# -------------

resource "aws_iam_role" "ec2_assume_role" {
  name = "ec2_assume_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_assume_role.name
}

resource "aws_iam_role_policy" "ec2_exec_policy" {
  name = "ec2_exec_policy"
  role = aws_iam_role.ec2_assume_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*", 
        "sqs:*", 
        "kinesis:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

data "aws_vpc" "selected_vpc" {
  id = var.ec2_vpc_id
}

resource "aws_subnet" "ec2_instance_subnet" {
  vpc_id            = data.aws_vpc.selected_vpc.id
  availability_zone = var.ec2_subnet_az
  cidr_block        = cidrsubnet(data.aws_vpc.selected_vpc.cidr_block, 8, 96)
}

resource "aws_security_group" "allow_ssh_sg" {
  name = "allow_ssh_sg"
  vpc_id = data.aws_vpc.selected_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  # Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "test_ec2_instance" {
  # Amazon Linux 2 AMI 2.0.20200520.1 x86_64 HVM gp2
  ami = var.ec2_ami_id
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups = [aws_security_group.allow_ssh_sg.name]
  key_name = var.ec2_ssh_keypair_name
  # user_data = file("startup_script_ec2.sh")
  # subnet_id = aws_subnet.ec2_instance_subnet.id

  tags = {
    app = "AWSGridWithSQS"
  }
}

resource "aws_sqs_queue" "grid_tasks_queue" {
  name                      = "grid_tasks_queue"
  delay_seconds             = 90
  max_message_size          = 2048 # 2kbs
  message_retention_seconds = 86400 # 1 day
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.grid_tasks_dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    app = "AWSGridWithSQS"
  }
}

resource "aws_sqs_queue" "grid_tasks_dlq" {
  name                      = "grid_tasks_dlq"
  tags = {
    app = "AWSGridWithSQS"
  }
}

output "ec2_dns_address" {
  value = "${aws_instance.test_ec2_instance.public_dns}"
}