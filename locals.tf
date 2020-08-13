locals {
  # Common tags to be assigned to all resources
  common_tags = {
    AppName               = var.app_name
    Environment           = var.aws_env
  }

  asg_instance_tags = [
    {
      key                 = "AppName"
      value               = var.app_name
      propagate_at_launch = true
    }, 
    {
      key                 = "Environment"
      value               = var.aws_env
      propagate_at_launch = true
    }
  ]
}