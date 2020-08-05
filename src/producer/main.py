import signal, sys
import logging, time, json, random
import boto3
from primeNumbers import generateLargePrime
from statsd import StatsClient

def exit_handler(sig, frame): 
  logging.info('Exit handler invoked, preparing to exit gracefully.')
  logging.shutdown()
  print('Goodbye!')
  sys.exit(0)

def loadParams():
  # create an ssm service client
  ssm = boto3.client('ssm')
  path = '/dev/AWSGridWithSQS/producer/'
  params = ssm.get_parameters_by_path(Path = path)
  if params and params['Parameters']: 
    for p in params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        LOG_FILENAME = v
      elif (n == 'stats_prefix'):
        STATS_PREFIX = v
      elif (n == 'stats_rate'):
        STATS_RATE = float(v)
      elif (n == 'tasks_queue_name'):
        TASKS_QUEUE_NAME = v
      elif (n == 'batch_size'):
        BATCH_SIZE = int(v)
      elif (n == 'prime_min_bits'):
        PRIME_MIN_BITS = int(v)
      elif (n == 'prime_max_bits'):
        PRIME_MAX_BITS = int(v)


def main():
  # get the service resource
  sqs = boto3.resource('sqs')

  # get the tasks queue
  tasks_queue = sqs.get_queue_by_name(QueueName=TASKS_QUEUE_NAME)

  # stats client writes to statsd daemon which then publishes to cloudwatch agent  
  statsd = StatsClient()
  statsdpipe = statsd.pipeline()

  while True: 
    # prepare a batch of task messages
    exec_timer = statsdpipe.timer(STATS_PREFIX + 'exec_time', rate=STATS_RATE).start()
    queue_entries = []
    for i in range (0, BATCH_SIZE): 
      bits = random.randint(PRIME_MIN_BITS, PRIME_MAX_BITS) 
      number = generateLargePrime(bits)

      req_obj = dict(input = number, type = 'Decimal')
      req_json = json.dumps(req_obj)

      queue_entries.append(dict(
        Id = str(i), 
        MessageBody = req_json
      ))
    exec_timer.stop() # exec_time

    # send the batch of task messages
    send_timer = statsdpipe.timer(STATS_PREFIX + 'send_msg_time', rate=STATS_RATE).start()
    try: 
      ack = tasks_queue.send_messages(Entries=queue_entries) 
      n = len(queue_entries)
      if ack: 
        statsdpipe.incr(STATS_PREFIX + 'throughput', n, rate=STATS_RATE) 
        logging.debug(f'Sent a batch of {n} task messages')
    except Exception as e:
      logging.error('Error sending task messages', exc_info=e)
    send_timer.stop() # send_msg_time
    statsdpipe.send()

# global variables with default values
LOG_FILENAME = '/var/log/AWSGridWithSQS/producer-main.log'
STATS_PREFIX = 'awsgridwithsqs_producer_'
STATS_RATE = 0.1 # rate = 1/10 as metrics_collection_interval = 10 seconds
TASKS_QUEUE_NAME = 'grid_tasks_queue'
BATCH_SIZE = 10
PRIME_MIN_BITS = 20
PRIME_MAX_BITS = 30

# main
if __name__ == '__main__':
  logging.basicConfig(filename=LOG_FILENAME, format='%(asctime)s - %(levelname)s - %(message)s', level=logging.DEBUG)
  signal.signal(signal.SIGINT, exit_handler)
  signal.signal(signal.SIGTERM, exit_handler)
  print('Press Ctrl+C to exit')
  loadParams()
  main()