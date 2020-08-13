# Running a High-Performance Computing (or HPC) grid on AWS

This code repository offers an example of running a High Performance Computing (HPC) grid workload on Amazon Web Services (AWS), centrally based on Amazon SQS and AWS Auto Scaling services. Amazon SQS is a highly performant and scalable message queuing service, while AWS Auto Scaling can be used to effortlessly manage a fleet of EC2 instances by scaling in or out capacity based on a defined policy. 

The software layer that operates the grid is written in `Python`. To simulate a problem for the grid to solve, the code uses a certain mathematical operation - prime number generation and factorization, that is computationally intensive and whose complexity can be easily controlled by changing a parameter (number size). It also uses a `statsd` client to send real-time metrics to Amazon CloudWatch, which is another AWS service that is heavily used in this project. 

The repo also provides Terraform based scripts to create the full deployment infrstructure. It has been tested using Terraform CLI `v0.12.0` along with AWS provider `v2.27.0`. 

## Overview

The grid architecture is very simple, and uses just a handful of AWS services. Figure below shows the AWS deployment architecture:

![AWS Deployment Architecture](./docs/images/AWSGridWithSQS-Figure-1.png)

There are 3 logical components within the software layer, each running on separate sets of EC2 instances (nodes) managed by AWS Auto Scaling groups as shown in the figure above: 
- Workers 
- Supervisors 
- Producers

`Producers` are responsible for generating requests and submitting them to a `Tasks Queue`. From there, `Workers` pick up and process each task, writing the results to a separate `Results Queue`. `Supervisors` are responsible for monitoring the tasks queue backlog, and ensuring `Workers` have sufficient capacity to handle the requests while minimizing delays. Throughput and performance of each node can be monitored via a CloudWatch dashboard. 

## Design

### 1. Building an AMI

![AMI creation pipeline using Hashicorp Packer](./docs/images/AWSGridWithSQS-Figure-2.png)

### 2. Running the grid

![Logical data flow in the grid](./docs/images/AWSGridWithSQS-Figure-3.png)

## Configurable Parameters

For each of the 3 components, there are a number of configurable parameters that can be defined via AWS Systems Manager Parameter Store. A prefix representating the environment is required for each parameter (default is `/dev`)

- Producer (`/AWSGridWithSQS/producer`)
  - `/log_filename` (default: /var/log/AWSGridWithSQS/producer-main.log) - must be a path that *ec2-user* account has write access to
  - `/log_level` (default: INFO) - supported values are `CRITICAL`, `ERROR`, `WARNING`, `INFO`, `DEBUG` and `NOTSET`
  - `/stats_prefix` (default: awsgridwithsqs_producer_) - prefix for custom metric names published to CloudWatch
  - `/tasks_queue_name` (default: grid_tasks_queue) - name of the tasks queue (must be created in the same region and AWS account)
  - `/batch_size` (default: 10) - number of requests to fetch from the tasks queue in each batch (range 1 and 10)
  - `/prime_min_bits` (default: 20) - lower bound for prime numbers would be 2^prime_min_bits
  - `/prime_max_bits` (default: 30) - upper bound for prime numbers would be 2^prime_max_bits

- Worker (`/AWSGridWithSQS/worker`)
  - `/log_filename` (default: /var/log/AWSGridWithSQS/worker-main.log)
  - `/log_level` (default: INFO)
  - `/queue_polling_wait_time` (default: 10)
  - `/queue_repolling_sleep_time` (default: 0)
  - `/visibility_timeout` (default: 120)
  - `/batch_size` (default: 10)
  - `/stats_prefix` (default: awsgridwithsqs_worker_)
  - `/tasks_queue_name` (default: grid_tasks_queue)
  - `/results_queue_name` (default: grid_results_queue)

- Supervisor (`/AWSGridWithSQS/worker`)
  - `/log_filename` (default: /var/log/AWSGridWithSQS/supervisor-main.log)
  - `/log_level` (default: INFO)
  - `/tasks_queue_name` (default: grid_tasks_queue)
  - `/worker_asg_name` (default: awsgrid-with-sqs-worker-asg)
  - `/supervisor_asg_name` (default: awsgrid-with-sqs-supervisor-asg)
  - `/metric_interval` (default: 15)

## License

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](http://badges.mit-license.org)

- **[MIT license](http://opensource.org/licenses/mit-license.php)**
- Copyright 2020 &copy; Sachin Hamirwasia
