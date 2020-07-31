# define grid_tasks_queue
resource "aws_sqs_queue" "grid_tasks_queue" {
  name                        = "grid_tasks_queue"
  delay_seconds               = 0
  max_message_size            = 2048 # 2kbs
  visibility_timeout_seconds  = 120 # 2 mins
  message_retention_seconds   = 3600 # 1 hr
  receive_wait_time_seconds   = 10
  redrive_policy              = jsonencode({
    deadLetterTargetArn       = aws_sqs_queue.grid_tasks_dlq.arn
    maxReceiveCount           = 4
  })

  tags = {
    app = "AWSGridWithSQS"
  }
}

resource "aws_sqs_queue" "grid_tasks_dlq" {
  name = "grid_tasks_dlq"
  tags = {
    app = "AWSGridWithSQS"
  }
}

# define grid_results_queue
resource "aws_sqs_queue" "grid_results_queue" {
  name                        = "grid_results_queue"
  delay_seconds               = 0
  max_message_size            = 2048 # 2kbs
  visibility_timeout_seconds  = 30 
  message_retention_seconds   = 1800 # 30 mins
  receive_wait_time_seconds   = 10
  redrive_policy              = jsonencode({
    deadLetterTargetArn       = aws_sqs_queue.grid_results_dlq.arn
    maxReceiveCount           = 4
  })

  tags = {
    app = "AWSGridWithSQS"
  }
}

resource "aws_sqs_queue" "grid_results_dlq" {
  name = "grid_results_dlq"
  tags = {
    app = "AWSGridWithSQS"
  }
}
