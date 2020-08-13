import os, signal, sys
import logging, logging.handlers
import re, time
import boto3
from threading import Timer

def exit_handler(sig, frame): 
  logging.info('Exit handler invoked, preparing to exit gracefully.')
  logging.shutdown()
  print('Goodbye!')
  sys.exit(0)


def loadParams(defaults):
  if not defaults: 
    raise ValueError('defaults must be a valid dictionary') 
  params = defaults.copy()

  # get AWS_ENV system environment variable
  env = os.getenv('AWS_ENV')
  valid_pattern = r'^[A-Za-z0-9_\-]{1,15}$'
  if env and re.match(valid_pattern, env):
    params['AWS_ENV'] = env 

  # create an ssm service client
  ssm = boto3.client('ssm')

  path = '/' + params['AWS_ENV'] + '/AWSGridWithSQS/supervisor/'
  ssm_params = ssm.get_parameters_by_path(Path = path)

  if ssm_params and ssm_params['Parameters']: 
    for p in ssm_params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        params['LOG_FILENAME'] = v
      elif (n == 'log_level'):
        params['LOG_LEVEL'] = v
      elif (n == 'tasks_queue_name'):
        params['TASKS_QUEUE_NAME'] = v
      elif (n == 'worker_asg_name'):
        params['WORKER_ASG_NAME'] = v
      elif (n == 'supervisor_asg_name'):
        params['SUPERVISOR_ASG_NAME'] = v
      elif (n == 'metric_interval'):
        params['METRIC_INTERVAL'] = int(v)
  return params


def main(params):
  # get service resources
  sqs = boto3.resource('sqs')
  asg = boto3.client('autoscaling')
  cw = boto3.client('cloudwatch')

  exception_count = 0
  while True:
    try: 
      st = time.time()
      tasks_queue = sqs.get_queue_by_name(QueueName=params['TASKS_QUEUE_NAME'])
      backlog_count = int(tasks_queue.attributes['ApproximateNumberOfMessages'])

      worker_asg_info = asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[ params['WORKER_ASG_NAME'] ]
      )
      desired_instances_count = int(worker_asg_info['AutoScalingGroups'][0]['DesiredCapacity'])
      #all_instances_count = len(worker_asg_info['AutoScalingGroups'][0]['Instances'])

      if desired_instances_count > 0: 
        backlog_per_instance = backlog_count / desired_instances_count
      else: 
        backlog_per_instance = backlog_count # we don't want to return 0 or less

      cw.put_metric_data(
        Namespace = 'AWSGridWithSQS/AppMetrics', 
        MetricData = [
          {
              'MetricName': 'backlog_per_instance',
              'Dimensions': [
                  {
                      'Name': 'AutoScalingGroupName',
                      'Value': params['SUPERVISOR_ASG_NAME']
                  },
              ],
              'Value': backlog_per_instance, 
              'Unit': 'Count',
              'StorageResolution': 1
          }
        ]
      )

      logging.info(f'Published metric data [backlog_per_instance] = {backlog_per_instance}')

      if (params['LOG_LEVEL'] == 'DEBUG'): 
        logging.debug(f'Tasks queue ApproximateNumberOfMessages = {backlog_count}')
        logging.debug(f'Worker ASG describe info = {worker_asg_info}')
        logging.debug(f'Worker ASG desired count = {desired_instances_count}')
        #logging.debug(f'Worker ASG instances count = {all_instances_count}')

      et = time.time() 
      dt = et - st
      if (dt < params['METRIC_INTERVAL']):
        time.sleep(params['METRIC_INTERVAL'] - dt)

      exception_count = 0 # reset exception count

    except Exception as e: 
      logging.error('Exception caught during supervisor looping', exc_info=e)
      exception_count += 1
      if (exception_count >= 3): 
        logging.error('Exception not resolved after 3 retries, exiting program')
        print('Exiting program after 3 consecutive exceptions!')
        break
      else:
        logging.error('Retrying after 30seconds...')
        time.sleep(30) # wait for 30 seconds


# global variables with default values
defaults = dict(
  AWS_ENV = 'dev', 
  LOG_FILENAME = '/var/log/AWSGridWithSQS/supervisor-main.log', 
  LOG_LEVEL = 'INFO', 
  MAX_LOG_FILESIZE = 10*1024*1024, # 10 Mbs
  TASKS_QUEUE_NAME = 'grid_tasks_queue', 
  WORKER_ASG_NAME = 'awsgrid-with-sqs-worker-asg', 
  SUPERVISOR_ASG_NAME = 'awsgrid-with-sqs-supervisor-asg', 
  METRIC_INTERVAL = 15, # send a metric every x seconds
)

# main
if __name__ == '__main__':
  params = loadParams(defaults)
  #logHandler = logging.handlers.RotatingFileHandler(params['LOG_FILENAME'], mode = 'a', maxBytes = params['MAX_LOG_FILESIZE'], backupCount = 5)
  #logging.basicConfig(handlers = [logHandler], format = '%(asctime)s - %(levelname)s - %(message)s', level = params['LOG_LEVEL'])
  logging.basicConfig(format = '%(asctime)s - %(levelname)s - %(message)s', level = params['LOG_LEVEL'])
  signal.signal(signal.SIGINT, exit_handler)
  signal.signal(signal.SIGTERM, exit_handler)
  print('Press Ctrl+C to exit')
  main(params)