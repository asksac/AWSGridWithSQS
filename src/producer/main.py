import os, signal, sys
import logging, logging.handlers
import json, random, re, time
import boto3
from primeNumbers import generateLargePrime
from statsd import StatsClient


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

  path = '/' + params['AWS_ENV'] + '/AWSGridWithSQS/producer/'
  ssm_params = ssm.get_parameters_by_path(Path = path)

  if ssm_params and ssm_params['Parameters']: 
    for p in ssm_params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        params['LOG_FILENAME'] = v
      elif (n == 'log_level'):
        params['LOG_LEVEL'] = v
      elif (n == 'stats_prefix'):
        params['STATS_PREFIX'] = v
      elif (n == 'tasks_queue_name'):
        params['TASKS_QUEUE_NAME'] = v
      elif (n == 'batch_size'):
        params['BATCH_SIZE'] = int(v)
      elif (n == 'prime_min_bits'):
        params['PRIME_MIN_BITS'] = int(v)
      elif (n == 'prime_max_bits'):
        params['PRIME_MAX_BITS'] = int(v)
  return params


def main(params):
  # get the service resource
  sqs = boto3.resource('sqs')

  # get the tasks queue
  tasks_queue = sqs.get_queue_by_name(QueueName=params['TASKS_QUEUE_NAME'])

  # stats client writes to statsd daemon which then publishes to cloudwatch agent  
  statsd = StatsClient()
  statsdpipe = statsd.pipeline()

  while True: 
    # prepare a batch of task messages
    exec_timer = statsdpipe.timer(params['STATS_PREFIX'] + 'exec_time', rate=params['STATS_RATE']).start()
    queue_entries = []
    for i in range (0, params['BATCH_SIZE']): 
      bits = random.randint(params['PRIME_MIN_BITS'], params['PRIME_MAX_BITS']) 
      number = generateLargePrime(bits)

      req_obj = dict(input = number, type = 'Decimal')
      req_json = json.dumps(req_obj)

      queue_entries.append(dict(
        Id = str(i), 
        MessageBody = req_json
      ))
    exec_timer.stop() # exec_time

    # send the batch of task messages
    send_timer = statsdpipe.timer(params['STATS_PREFIX'] + 'send_msg_time', rate=params['STATS_RATE']).start()
    try: 
      ack = tasks_queue.send_messages(Entries=queue_entries) 
      n = len(queue_entries)
      if ack: 
        statsdpipe.incr(params['STATS_PREFIX'] + 'throughput', n, rate=params['STATS_RATE']) 
        logging.debug(f'Sent a batch of {n} task messages')
    except Exception as e:
      logging.error('Error sending task messages', exc_info=e)
    send_timer.stop() # send_msg_time
    statsdpipe.send()

# define default parameter values
defaults = dict(
  AWS_ENV             = 'dev', 
  LOG_FILENAME        = '/var/log/AWSGridWithSQS/producer-main.log', 
  LOG_LEVEL           = 'INFO', 
  MAX_LOG_FILESIZE    = 10*1024*1024, # 10 Mbs
  STATS_PREFIX        = 'awsgridwithsqs_producer_', 
  STATS_RATE          = 1, 
  TASKS_QUEUE_NAME    = 'grid_tasks_queue', 
  BATCH_SIZE          = 10, 
  PRIME_MIN_BITS      = 20, 
  PRIME_MAX_BITS      = 30, 
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