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

# Worker ASG

data "template_file" "worker_user_data_script" {
  template = <<EOF
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export AWS_ENV='${var.aws_env}'
sudo -b -u ec2-user python3 /home/ec2-user/AWSGridWithSQS/src/worker/main.py
EOF
}

resource "aws_launch_template" "worker_launch_template" {
  name_prefix                   = "awsgrid-worker-lc-"
  description                   = "Worker autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = data.aws_ami.ec2_ami.id
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
  #placement {
  #  availability_zone           = var.ec2_subnet_az
  #}
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true 
    security_groups             = [ aws_security_group.allow_ssh_sg.id ]
  }

  monitoring {
    enabled                     = true
  }

  #user_data                     = filebase64("launch_script_worker.sh")
  user_data                     = base64encode(data.template_file.worker_user_data_script.template) 

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags                        = local.common_tags
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                  = "awsgrid-with-sqs-worker-asg"
  min_size              = 0
  max_size              = 2000
  desired_capacity      = 0
  health_check_type     = "EC2"
  vpc_zone_identifier   = [
    aws_subnet.ec2_instance_subnet_1.id, 
    aws_subnet.ec2_instance_subnet_2.id
  ]
  launch_template {
    id      = aws_launch_template.worker_launch_template.id
    version = "$Latest"
  }
  metrics_granularity   = "1Minute"
  enabled_metrics       = ["GroupDesiredCapacity", "GroupInServiceInstances"]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,
    ]
  }

  depends_on            = [ aws_launch_template.producer_launch_template ]

  tags                  = concat(
    [
      {
        key = "Name"
        value = "awsgrid-workers"
        propagate_at_launch = true
      }
    ], 
    local.asg_instance_tags
  )
}

resource "aws_autoscaling_policy" "workers_target_policy" {
  name                        = "awsgrid-workers-target-policy"
  policy_type                 = "TargetTrackingScaling"
  estimated_instance_warmup   = 30
  autoscaling_group_name      = aws_autoscaling_group.worker_asg.name

  target_tracking_configuration {
    customized_metric_specification {
      namespace   = "AWSGridWithSQS/AppMetrics"
      metric_dimension {
        name  = "AutoScalingGroupName"
        value = "awsgrid-with-sqs-supervisor-asg"
      }
      metric_name = "backlog_per_instance"
      statistic   = "Minimum"
    }
    target_value = 5000
  }
}

/*
resource "aws_autoscaling_policy" "workers_incr_policy" {
  name                        = "awsgrid-workers-incr-policy"
  scaling_adjustment          = 1
  adjustment_type             = "ChangeInCapacity"
  cooldown                    = 180 # 3 minutes
  autoscaling_group_name      = aws_autoscaling_group.worker_asg.name
}

resource "aws_autoscaling_policy" "workers_decr_policy" {
  name                   = "awsgrid-workers-decr-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
}
*/

# Producer ASG

data "template_file" "producer_user_data_script" {
  template = <<EOF
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export AWS_ENV='${var.aws_env}'
sudo -b -u ec2-user python3 /home/ec2-user/AWSGridWithSQS/src/producer/main.py
EOF
}

resource "aws_launch_template" "producer_launch_template" {
  name_prefix                   = "awsgrid-producer-lc-"
  description                   = "Producer autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = data.aws_ami.ec2_ami.id
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
  #placement {
  #  availability_zone           = var.ec2_subnet_az
  #}
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true 
    security_groups             = [ aws_security_group.allow_ssh_sg.id ]
    #subnet_id                   = aws_subnet.ec2_instance_subnet.id
  }

  monitoring {
    enabled                     = true
  }

  #user_data                     = filebase64("launch_script_producer.sh")
  user_data                     = base64encode(data.template_file.producer_user_data_script.template) 

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags                        = local.common_tags
  }
}

resource "aws_autoscaling_group" "producer_asg" {
  name                  = "awsgrid-with-sqs-producer-asg"
  min_size              = 0
  max_size              = 500
  desired_capacity      = 0
  health_check_type     = "EC2"
  vpc_zone_identifier   = [
    aws_subnet.ec2_instance_subnet_1.id, 
    aws_subnet.ec2_instance_subnet_2.id
  ]
  launch_template {
    id                  = aws_launch_template.producer_launch_template.id
    version             = "$Latest"
  }
  metrics_granularity   = "1Minute"
  enabled_metrics       = ["GroupDesiredCapacity", "GroupInServiceInstances"]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,
    ]
  }

  depends_on            = [ aws_launch_template.producer_launch_template ]

  tags                  = concat(
    [
      {
        key = "Name"
        value = "awsgrid-producers"
        propagate_at_launch = true
      }
    ], 
    local.asg_instance_tags
  )
}

# Supervisor ASG

data "template_file" "supervisor_user_data_script" {
  template = <<EOF
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export AWS_ENV='${var.aws_env}'
sudo -b -u ec2-user python3 /home/ec2-user/AWSGridWithSQS/src/supervisor/main.py
EOF
}

resource "aws_launch_template" "supervisor_launch_template" {
  name_prefix                   = "awsgrid-supervisor-lc-"
  description                   = "Supervisor autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = data.aws_ami.ec2_ami.id
  instance_type                 = "t3.small" # t3.nano is too slow to startup

  iam_instance_profile {
    name                        = aws_iam_instance_profile.ec2_instance_profile.name
  } 
  key_name                      = var.ec2_ssh_keypair_name
  #vpc_security_group_ids        = [ aws_security_group.allow_ssh_sg.id ]
  #placement {
  #  availability_zone           = var.ec2_subnet_az
  #}
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true 
    security_groups             = [ aws_security_group.allow_ssh_sg.id ]
    #subnet_id                   = aws_subnet.ec2_instance_subnet.id
  }

  monitoring {
    enabled                     = true
  }

  #user_data                     = filebase64("launch_script_supervisor.sh")
  user_data                     = base64encode(data.template_file.supervisor_user_data_script.template) 

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags                        = local.common_tags
  }
}

resource "aws_autoscaling_group" "supervisor_asg" {
  name                  = "awsgrid-with-sqs-supervisor-asg"
  min_size              = 0
  max_size              = 2
  desired_capacity      = 0
  health_check_type     = "EC2"
  vpc_zone_identifier   = [
    aws_subnet.ec2_instance_subnet_1.id, 
    aws_subnet.ec2_instance_subnet_2.id
  ]
  launch_template {
    id      = aws_launch_template.supervisor_launch_template.id
    version = "$Latest"
  }
  metrics_granularity   = "1Minute"
  enabled_metrics       = ["GroupDesiredCapacity", "GroupInServiceInstances"]

  lifecycle {
    create_before_destroy = true
  }

  depends_on            = [ aws_launch_template.supervisor_launch_template ]

  tags                  = concat(
    [
      {
        key = "Name"
        value = "awsgrid-supervisor"
        propagate_at_launch = true
      }
    ], 
    local.asg_instance_tags
  )
}

/*
resource "aws_instance" "test_instance" {
  # Amazon Linux 2 AMI 2.0.20200520.1 x86_64 HVM gp2
  ami = data.aws_ami.ec2_ami.id
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups = [aws_security_group.allow_ssh_sg.name]
  key_name = var.ec2_ssh_keypair_name
  # user_data = file("startup_script_ec2.sh")
  # subnet_id = aws_subnet.ec2_instance_subnet.id

  tags = local.common_tags
}
*/
