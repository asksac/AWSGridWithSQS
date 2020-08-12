resource "aws_cloudwatch_log_group" "cw_supervisors_log_group" {
  name                      = "AWSGridWithSQS/Logs/Supervisors"

  tags = {
    app                     = "AWSGridWithSQS"
  }
}

resource "aws_cloudwatch_log_group" "cw_workers_log_group" {
  name                      = "AWSGridWithSQS/Logs/Workers"

  tags = {
    app                     = "AWSGridWithSQS"
  }
}

resource "aws_cloudwatch_log_group" "cw_producers_log_group" {
  name                      = "AWSGridWithSQS/Logs/Producers"

  tags = {
    app                      = "AWSGridWithSQS"
  }
}

/*
resource "aws_cloudwatch_metric_alarm" "tasks_backlog_high_alarm" {
  alarm_name                = "awsgrid_task_backlog_high_alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2" # 2 periods of 60 seconds periods (total 2 minutes refresh)
  threshold                 = "5000"
  alarm_description         = "Backlog Per Instance is above 5000 or about 28s latency based on TPS"
  
  alarm_actions             = [aws_autoscaling_policy.workers_incr_policy.arn]

  metric_query {
    id                      = "backlog_per_instance"
    expression              = "pt/wrc"
    label                   = "Backlog Per Instance"
    return_data             = "true"
  }

  metric_query {
    id                      = "pt" # pending_tasks

    metric {
      metric_name           = "ApproximateNumberOfMessagesVisible"
      namespace             = "AWS/SQS"
      period                = "60"
      stat                  = "Average"

      dimensions = {
        QueueName           = "grid_tasks_queue"
      }
    }
  }

  metric_query {
    id                      = "wrc" # workers_asg_running_capacity

    metric {
      metric_name           = "GroupInServiceInstances"
      namespace             = "AWS/AutoScaling"
      period                = "60"
      stat                  = "Average"

      dimensions = {
        AutoScalingGroupName = "awsgrid-with-sqs-worker-asg"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "tasks_backlog_low_alarm" {
  alarm_name                = "awsgrid_task_backlog_low_alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2" # 2 periods of 60 seconds periods (total 2 minutes refresh)
  threshold                 = "4000"
  alarm_description         = "Backlog Per Instance is under 4000 or about 22s latency based on TPS"
  
  alarm_actions             = [aws_autoscaling_policy.workers_decr_policy.arn]

  metric_query {
    id                      = "backlog_per_instance"
    expression              = "pt/wrc"
    label                   = "Backlog Per Instance"
    return_data             = "true"
  }

  metric_query {
    id                      = "pt" # pending_tasks

    metric {
      metric_name           = "ApproximateNumberOfMessagesVisible"
      namespace             = "AWS/SQS"
      period                = "60"
      stat                  = "Average"

      dimensions = {
        QueueName           = "grid_tasks_queue"
      }
    }
  }

  metric_query {
    id                      = "wrc" # workers_asg_running_capacity

    metric {
      metric_name           = "GroupInServiceInstances"
      namespace             = "AWS/AutoScaling"
      period                = "60"
      stat                  = "Average"

      dimensions = {
        AutoScalingGroupName = "awsgrid-with-sqs-worker-asg"
      }
    }
  }
}
*/

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "AWSGridWithSQS_Main_Dashboard"

  dashboard_body = <<EOF
  {
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
              "metrics": [
                  [ "AWSGridWithSQS/AppMetrics", "awsgridwithsqs_producer_throughput", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg", { "label": "Producer TPS [Avg: $${AVG}]", "id": "m1" } ]
              ],
              "view": "timeSeries",
              "stacked": true,
              "region": "us-east-1",
              "period": 60,
              "stat": "Average",
              "yAxis": {
                  "left": {
                      "showUnits": false,
                      "label": "Per Second"
                  }
              },
              "title": "Producer Throughput (TPS)"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "grid_tasks_queue" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "period": 60,
                "title": "Tasks Queue Backlog",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                },
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWSGridWithSQS/AppMetrics", "awsgridwithsqs_worker_tps", "AutoScalingGroupName", "awsgrid-with-sqs-worker-asg", { "label": "Worker TPS [Avg: $${AVG}]", "id": "m1" } ]
                ],
                "view": "timeSeries",
                "stacked": true,
                "region": "us-east-1",
                "period": 60,
                "stat": "Average",
                "yAxis": {
                    "left": {
                        "showUnits": false,
                        "label": "Per Second"
                    }
                },
                "title": "Worker Throughput (TPS)"
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "grid_results_queue" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "Results Queue Message Count",
                "period": 60,
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                },
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 6,
            "height": 3,
            "properties": {
                "metrics": [
                    [ "AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg" ]
                ],
                "view": "singleValue",
                "region": "us-east-1",
                "title": "Producer In Service Instances",
                "period": 60,
                "stat": "p99"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 6,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg" ],
                    [ ".", "GroupDesiredCapacity", ".", "." ]
                ],
                "region": "us-east-1",
                "title": "Producer ASG Capacity"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 6,
            "height": 3,
            "properties": {
                "metrics": [
                    [ "AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "awsgrid-with-sqs-worker-asg" ]
                ],
                "view": "singleValue",
                "region": "us-east-1",
                "title": "Worker In Service Instances",
                "period": 60,
                "stat": "p99"
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 6,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "awsgrid-with-sqs-worker-asg" ],
                    [ ".", "GroupInServiceInstances", ".", "." ]
                ],
                "region": "us-east-1",
                "title": "Worker ASG Capacity",
                "period": 60
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 9,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                  [ "AWSGridWithSQS/AppMetrics", "cpu_usage_user", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg", { "id": "m1", "label": "User CPU Usage [Avg: $${AVG}]" } ],
                  [ ".", "cpu_usage_system", ".", ".", { "id": "m2", "label": "System CPU Usage [Avg: $${AVG}]" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "stat": "Average",
                "period": 60,
                "title": "Producers CPU Utilization"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 9,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWSGridWithSQS/AppMetrics", "awsgridwithsqs_producer_send_msg_time", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg", { "label": "Batch Send Message Time" } ],
                    [ "AWSGridWithSQS/AppMetrics", "awsgridwithsqs_producer_exec_time", "AutoScalingGroupName", "awsgrid-with-sqs-producer-asg", { "label": "Batch Execution Time" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "Producer Nodes Performance",
                "stat": "Average",
                "period": 60,
                "yAxis": {
                    "left": {
                        "showUnits": false,
                        "label": "Milliseconds"
                    }
                }
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 9,
            "width": 6,
            "height": 6,
            "properties": {
              "metrics": [
                  [ "AWSGridWithSQS/AppMetrics", "cpu_usage_user", "AutoScalingGroupName", "awsgrid-with-sqs-worker-asg", { "id": "m1", "label": "User CPU Usage [Avg: $${AVG}]" } ],
                  [ ".", "cpu_usage_system", ".", ".", { "id": "m2", "label": "System CPU Usage [Avg: $${AVG}]" } ]
              ],
              "view": "timeSeries",
              "stacked": false,
              "region": "us-east-1",
              "stat": "Average",
              "period": 60,
              "title": "Workers CPU Utilization"
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 9,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWSGridWithSQS/AppMetrics", "awsgridwithsqs_worker_read_time", "AutoScalingGroupName", "awsgrid-with-sqs-worker-asg", { "label": "Batch Read Message Time" } ],
                    [ ".", "awsgridwithsqs_worker_send_time", ".", ".", { "label": "Batch Send Message Time" } ],
                    [ ".", "awsgridwithsqs_worker_delete_time", ".", ".", { "label": "Batch Delete Message Time" } ],
                    [ ".", "awsgridwithsqs_worker_execution_time", ".", ".", { "label": "Batch Execution Time" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "Worker Nodes Performance",
                "stat": "Average",
                "period": 60,
                "yAxis": {
                    "left": {
                        "showUnits": false,
                        "label": "Milliseconds"
                    }
                }
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 15,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "Currency", "USD", { "id": "m1" } ],
                    [ "...", "AmazonCloudWatch", ".", ".", { "id": "m2" } ],
                    [ "...", "AWSQueueService", ".", ".", { "id": "m3" } ],
                    [ "...", "AmazonVPC", ".", ".", { "id": "m4" } ]
                ],
                "view": "bar",
                "stacked": true,
                "region": "us-east-1",
                "title": "AWS Billing",
                "period": 21600,
                "setPeriodToTimeRange": true,
                "stat": "Maximum"
            }
        }, 
        {
            "type": "metric",
            "x": 6,
            "y": 15,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWSGridWithSQS/AppMetrics", "backlog_per_instance", "AutoScalingGroupName", "awsgrid-with-sqs-supervisor-asg", { "label": "BacklogPerInstance [last: $${LAST}]" } ]
                ],
                "view": "timeSeries",
                "stacked": true,
                "region": "us-east-1",
                "title": "Backlog Per Instance",
                "stat": "Average",
                "period": 30,
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 15,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/SQS", "NumberOfMessagesSent", "QueueName", "grid_results_dlq", { "label": "Results DLQ Count" } ],
                    [ "...", "grid_tasks_dlq", { "label": "Tasks DLQ Count" } ]
                ],
                "view": "timeSeries",
                "stacked": true,
                "region": "us-east-1",
                "title": "Dead Letter Queue Volume",
                "stat": "Average",
                "period": 60,
                "setPeriodToTimeRange": true
            }
        },
        {
            "type": "metric",
            "x": 18,
            "y": 15,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "NetworkPacketsIn", "AutoScalingGroupName", "Producer-asg" ],
                    [ "...", "Worker-asg" ],
                    [ ".", "NetworkPacketsOut", ".", "Producer-asg" ],
                    [ "...", "Worker-asg" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "us-east-1",
                "title": "Network Packets In/Out",
                "stat": "Average",
                "period": 60,
                "setPeriodToTimeRange": true
            }
        }
    ]
}
EOF
}
