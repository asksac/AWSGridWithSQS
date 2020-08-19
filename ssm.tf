locals {
  producer_path = "/${var.aws_env}/AWSGridWithSQS/producer"
  supervisor_path = "/${var.aws_env}/AWSGridWithSQS/supervisor"
  worker_path = "/${var.aws_env}/AWSGridWithSQS/worker"
}

resource "aws_ssm_parameter" "producer_batch_size" {
  description = "Producer Tasks Batch Size (Range 1 to 10)"
  type        = "String"
  name        = "${local.producer_path}/batch_size"
  value       = var.producer_batch_size
  overwrite   = true
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "producer_prime_min_bits" {
  description = "Producer Prime Number Minimum Bitsize"
  type        = "String"
  name        = "${local.producer_path}/prime_min_bits"
  value       = var.producer_prime_min_bits
  overwrite   = true
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "producer_prime_max_bits" {
  description = "Producer Prime Number Maximum Bitsize"
  type        = "String"
  name        = "${local.producer_path}/prime_max_bits"
  value       = var.producer_prime_max_bits
  overwrite   = true
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "supervisor_metric_interval" {
  description = "Supervisor Metric Interval in Seconds (Default 15)"
  type        = "String"
  name        = "${local.supervisor_path}/metric_interval"
  value       = var.supervisor_metric_interval
  overwrite   = true
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "worker_batch_size" {
  description = "Worker Batch Size (1 to 10, default 10)"
  type        = "String"
  name        = "${local.worker_path}/batch_size"
  value       = var.worker_batch_size
  overwrite   = true
  tags        = local.common_tags
}
