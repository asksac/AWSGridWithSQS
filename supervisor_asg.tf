resource "aws_launch_template" "supervisor_launch_template" {
  name_prefix                   = "awsgrid-supervisor-lc-"
  description                   = "Supervisor autoscale launch template"

  cpu_options {
    core_count                  = 1
    threads_per_core            = 1
  }
  image_id                      = var.ec2_ami_id
  instance_type                 = "t3.nano"

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

  user_data                     = filebase64("launch_script_supervisor.sh")

  lifecycle {
    create_before_destroy       = true
  }

  tag_specifications {
    resource_type               = "instance"
    tags = {
      app = "AWSGridWithSQS"
      component = "supervisor"
    }
  }
}

resource "aws_autoscaling_group" "supervisor_asg" {
  name                  = "awsgrid-with-sqs-supervisor-asg"
  min_size              = 1
  max_size              = 2
  desired_capacity      = 1
  health_check_type     = "EC2"
  vpc_zone_identifier   = [aws_subnet.ec2_instance_subnet.id]
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

  tag {
    key = "Name"
    value = "awsgrid-supervisor"
    propagate_at_launch = true
  }
}
