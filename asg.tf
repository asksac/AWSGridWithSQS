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

resource "aws_launch_template" "worker_launch_template" {
  name_prefix                   = "awsgrid-worker-lc-"
  description                   = "Worker autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = var.ec2_ami_id
  instance_type                 = "c5.large"
  instance_market_options {
    market_type                 = "spot"
    spot_options {
      spot_instance_type        = "one-time"
      max_price                 = "0.045"
    } 
  }

  iam_instance_profile {
    name                        = aws_iam_instance_profile.ec2_instance_profile.name
  } 
  key_name                      = var.ec2_ssh_keypair_name
  #vpc_security_group_ids        = [ aws_security_group.allow_ssh_sg.id ]
  placement {
    availability_zone           = var.ec2_subnet_az
  }
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true 
    security_groups             = [ aws_security_group.allow_ssh_sg.id ]
    subnet_id                   = aws_subnet.ec2_instance_subnet.id
  }

  monitoring {
    enabled                     = false
  }

  user_data                     = filebase64("launch_script_worker.sh")

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags = {
      app = "AWSGridWithSQS"
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                  = "awsgrid-with-sqs-worker-asg"
  min_size              = 1
  max_size              = 500
  desired_capacity      = 2
  health_check_type     = "EC2"
  vpc_zone_identifier   = [aws_subnet.ec2_instance_subnet.id]
  launch_template {
    id      = aws_launch_template.worker_launch_template.id
    version = "$Latest"
  }
  metrics_granularity   = "1Minute"
  enabled_metrics       = ["GroupDesiredCapacity", "GroupInServiceInstances"]

  lifecycle {
    create_before_destroy = true
  }

  depends_on            = [ aws_launch_template.producer_launch_template ]

  tag {
    key = "Name"
    value = "awsgrid-workers"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "workers_incr_policy" {
  name                   = "awsgrid-workers-incr-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180 # 3 minutes
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

resource "aws_autoscaling_policy" "workers_decr_policy" {
  name                   = "awsgrid-workers-decr-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}

resource "aws_launch_template" "producer_launch_template" {
  name_prefix                   = "awsgrid-producer-lc-"
  description                   = "Producer autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = var.ec2_ami_id
  instance_type                 = "c5.large"
  instance_market_options {
    market_type                 = "spot"
    spot_options {
      spot_instance_type        = "one-time"
      max_price                 = "0.045"
    } 
  }

  iam_instance_profile {
    name                        = aws_iam_instance_profile.ec2_instance_profile.name
  } 
  key_name                      = var.ec2_ssh_keypair_name
  #vpc_security_group_ids        = [ aws_security_group.allow_ssh_sg.id ]
  placement {
    availability_zone           = var.ec2_subnet_az
  }
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true 
    security_groups             = [ aws_security_group.allow_ssh_sg.id ]
    subnet_id                   = aws_subnet.ec2_instance_subnet.id
  }

  monitoring {
    enabled                     = false
  }

  user_data                     = filebase64("launch_script_producer.sh")

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags = {
      app = "AWSGridWithSQS"
    }
  }
}

resource "aws_autoscaling_group" "producer_asg" {
  name                  = "awsgrid-with-sqs-producer-asg"
  min_size              = 1
  max_size              = 10
  desired_capacity      = 1
  health_check_type     = "EC2"
  vpc_zone_identifier   = [aws_subnet.ec2_instance_subnet.id]
  launch_template {
    id      = aws_launch_template.producer_launch_template.id
    version = "$Latest"
  }
  metrics_granularity   = "1Minute"
  enabled_metrics       = ["GroupDesiredCapacity", "GroupInServiceInstances"]

  lifecycle {
    create_before_destroy = true
  }

  depends_on            = [ aws_launch_template.producer_launch_template ]

  tag {
    key = "Name"
    value = "awsgrid-producers"
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
