resource "aws_cloudwatch_log_group" "cw_workers_log_group" {
  name = "AWSGridWithSQS/Logs/Workers"

  tags = {
    app = "AWSGridWithSQS"
  }
}

resource "aws_cloudwatch_log_group" "cw_producers_log_group" {
  name = "AWSGridWithSQS/Logs/Producers"

  tags = {
    app = "AWSGridWithSQS"
  }
}
