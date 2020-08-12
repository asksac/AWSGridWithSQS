resource "aws_iam_role" "ec2_assume_role" {
  name = "ec2_assume_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      app = "AWSGridWithSQS"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_assume_role.name
}

resource "aws_iam_role_policy" "ec2_exec_policy" {
  name = "ec2_exec_policy"
  role = aws_iam_role.ec2_assume_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:*", 
        "sqs:GetQueueAttributes", 
        "sqs:GetQueueUrl", 
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter", 
        "cloudwatch:PutMetricData", 
        "autoscaling:DescribeAutoScalingGroups", 
        "autoscaling:DescribePolicies"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

data "aws_iam_policy" "cloudwatch_agent_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_assume_role_cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_assume_role.name
  policy_arn = data.aws_iam_policy.cloudwatch_agent_server_policy.arn
}
