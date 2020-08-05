import signal, sys
import logging, time, json, random
import boto3
from threading import Timer

def exit_handler(sig, frame): 
  logging.info('Exit handler invoked, preparing to exit gracefully.')
  logging.shutdown()
  print('Goodbye!')
  sys.exit(0)


def loadParams():
  # create an ssm service client
  ssm = boto3.client('ssm')
  path = '/dev/AWSGridWithSQS/supervisor/'
  params = ssm.get_parameters_by_path(Path = path)
  if params and params['Parameters']: 
    for p in params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        LOG_FILENAME = v
      elif (n == 'log_level'):
        LOG_LEVEL = v
      elif (n == 'tasks_queue_name'):
        TASKS_QUEUE_NAME = v
      elif (n == 'worker_asg_name'):
        WORKER_ASG_NAME = v
      elif (n == 'supervisor_asg_name'):
        SUPERVISOR_ASG_NAME = v
      elif (n == 'metric_interval'):
        METRIC_INTERVAL = int(v)


def main():
  # get service resources
  sqs = boto3.resource('sqs')
  asg = boto3.client('autoscaling')
  cw = boto3.client('cloudwatch')

  while True:
    try: 
      st = time.time()
      tasks_queue = sqs.get_queue_by_name(QueueName=TASKS_QUEUE_NAME)
      backlog_count = int(tasks_queue.attributes['ApproximateNumberOfMessages'])

      worker_asg_info = asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[ WORKER_ASG_NAME ]
      )
      desired_instances_count = int(worker_asg_info['AutoScalingGroups'][0]['DesiredCapacity'])
      #all_instances_count = len(worker_asg_info['AutoScalingGroups'][0]['Instances'])

      backlog_per_instance = backlog_count / desired_instances_count

      cw.put_metric_data(
        Namespace = 'AWSGridWithSQS/AppMetrics', 
        MetricData = [
          {
              'MetricName': 'backlog_per_instance',
              'Dimensions': [
                  {
                      'Name': 'AutoScalingGroupName',
                      'Value': SUPERVISOR_ASG_NAME
                  },
              ],
              'Value': backlog_per_instance, 
              'Unit': 'Count',
              'StorageResolution': 1
          }
        ]
      )

      if (LOG_LEVEL == 'DEBUG'): 
        logging.debug(f'Tasks queue ApproximateNumberOfMessages = {backlog_count}')
        logging.debug(f'Worker ASG describe info = {worker_asg_info}')
        logging.debug(f'Worker ASG desired count = {desired_instances_count}')
        #logging.debug(f'Worker ASG instances count = {all_instances_count}')
        logging.debug(f'Published metric data [backlog_per_instance] = {backlog_per_instance}')

      et = time.time() 
      dt = et - st
      if (dt < METRIC_INTERVAL):
        time.sleep(METRIC_INTERVAL - dt)

      exception_count = 0 # reset exception count

    except Exception as e: 
      exception_count += 1
      if (exception_count >= 3): 
        logging.error('Exception not resolved after 3 retries, exiting program')
        print('Exiting program after exceeding exception retry counter!')
        break
      else:
        logging.error('Exception caught during supervisor looping', exc_info=e)
        logging.error('Retrying after 30seconds...')
        time.sleep(30) # wait for 30 seconds


# global variables with default values
LOG_FILENAME = '/var/log/AWSGridWithSQS/supervisor-main.log'
LOG_LEVEL = 'INFO'
TASKS_QUEUE_NAME = 'grid_tasks_queue'
WORKER_ASG_NAME = 'awsgrid-with-sqs-worker-asg'
SUPERVISOR_ASG_NAME = 'awsgrid-with-sqs-supervisor-asg'
METRIC_INTERVAL = 15 # send a metric every x seconds

# main
if __name__ == '__main__':
  logging.basicConfig(filename=LOG_FILENAME, format='%(asctime)s - %(levelname)s - %(message)s', level=LOG_LEVEL)
  signal.signal(signal.SIGINT, exit_handler)
  signal.signal(signal.SIGTERM, exit_handler)
  print('Press Ctrl+C to exit')
  loadParams()
  main()      
