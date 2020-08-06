locals {
  producer_path = "/dev/AWSGridWithSQS/producer"
  supervisor_path = "/dev/AWSGridWithSQS/supervisor"
}

resource "aws_ssm_parameter" "producer_batch_size" {
  description = "Producer Tasks Batch Size (Range 1 to 10)"
  type        = "String"
  name        = "${local.producer_path}/batch_size"
  value       = "10"
  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_ssm_parameter" "producer_prime_min_bits" {
  description = "Producer Prime Number Minimum Bitsize"
  type        = "String"
  name        = "${local.producer_path}/prime_min_bits"
  value       = "25"
  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_ssm_parameter" "producer_prime_max_bits" {
  description = "Producer Prime Number Maximum Bitsize"
  type        = "String"
  name        = "${local.producer_path}/prime_max_bits"
  value       = "35"
  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_ssm_parameter" "producer_stats_rate" {
  description = "Producer Stats Rate for Metric (0 to 1)"
  type        = "String"
  name        = "${local.producer_path}/stats_rate"
  value       = "0.1"
  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_ssm_parameter" "supervisor_stats_rate" {
  description = "Supervisor Metric Interval in Seconds (Default 30)"
  type        = "String"
  name        = "${local.supervisor_path}/metric_interval"
  value       = "10"
  tags = {
      app = "AWSGridWithSQS"
  }
}

