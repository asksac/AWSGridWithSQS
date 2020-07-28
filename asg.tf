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

resource "aws_launch_configuration" "worker_launch_config" {
  name_prefix                 = "grid-with-sqs-lc-"
  image_id                    = var.ec2_ami_id
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups             = [aws_security_group.allow_ssh_sg.id]
  key_name                    = var.ec2_ssh_keypair_name
  associate_public_ip_address = true
  user_data                  = file("startup_script_ec2.sh")
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                  = "awsgrid-with-sqs-worker-asg"
  min_size              = 1
  max_size              = 1
  desired_capacity      = 1
  health_check_type     = "EC2"
  vpc_zone_identifier   = [aws_subnet.ec2_instance_subnet.id]
  launch_configuration  = aws_launch_configuration.worker_launch_config.name

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key = "Name"
    value = "awsgrid-with-sqs"
    propagate_at_launch = true
  }
}

/*
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
*/
