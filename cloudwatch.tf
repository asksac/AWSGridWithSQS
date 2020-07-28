resource "aws_cloudwatch_log_group" "cw_log_group" {
  name = "AWSGridWithSQS-Logs"

  tags = {
    app = "AWSGridWithSQS"
  }
}
