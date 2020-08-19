variable "app_name" {
  type          = string
  default       = "AWSGridWithSQS"
}

variable "app_shortcode" {
  type          = string
  default       = "awsgrid"
}

variable "aws_env" {
  type          = string
  default       = "dev"
  description   = "Specify an AWS_ENV value, e.g. dev, test, uat, prod"
}

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
  type          = string
  default       = "us-east-1a"
}

variable "ec2_subnet_az_2" {
  type          = string
  default       = "us-east-1b"
}

variable "ec2_ssh_keypair_name" {
  type          = string
  description   = "Specify the name of an existing SSH keypair"
}

# Parameter Store values 

variable "producer_batch_size" {
  type          = string
  default       = "10"
  description   = "Producer Tasks Batch Size (Range 1 to 10)"
}

variable "producer_prime_min_bits" {
  type          = string
  default       = "20"
  description   = "Producer Prime Number Minimum Bitsize"
}

variable "producer_prime_max_bits" {
  type          = string
  default       = "30"
  description   = "Producer Prime Number Maximum Bitsize"
}

variable "supervisor_metric_interval" {
  type          = string
  default       = "15"
  description   = "Supervisor Metric Interval in Seconds (Default 15)"
}

variable "worker_batch_size" {
  type          = string
  default       = "10"
  description   = "Worker Batch Size (1 to 10, default 10)"
}
