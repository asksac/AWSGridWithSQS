import signal, sys
import logging, logging.handlers
import time, json, random
import boto3
from factorizeInteger import factorize
from statsd import StatsClient

def exit_handler(sig, frame): 
  logging.info('Exit handler invoked, preparing to exit gracefully.')
  logging.shutdown()
  print('Goodbye!')
  sys.exit(0)


def loadParams():
  # create an ssm service client
  ssm = boto3.client('ssm')
  path = '/dev/AWSGridWithSQS/worker/'
  params = ssm.get_parameters_by_path(Path = path)
  if params and params['Parameters']: 
    for p in params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        LOG_FILENAME = v
      elif (n == 'log_level'):
        LOG_LEVEL = v
      elif (n == 'queue_polling_wait_time'):
        QUEUE_POLLING_WAIT_TIME = int(v)
      elif (n == 'queue_repolling_sleep_time'):
        QUEUE_REPOLLING_SLEEP_TIME = int(v)
      elif (n == 'visibility_timeout'):
        VISIBILITY_TIMEOUT = int(v)
      elif (n == 'batch_size'):
        BATCH_SIZE = int(v)
      elif (n == 'stats_prefix'):
        STATS_PREFIX = v
      elif (n == 'stats_rate'):
        STATS_RATE = float(v)
      elif (n == 'tasks_queue_name'):
        TASKS_QUEUE_NAME = v
      elif (n == 'results_queue_name'):
        RESULTS_QUEUE_NAME = v


# polls an SQS queue continuously and processes requests 
def main(): 
  # Get the service resource
  sqs = boto3.resource('sqs')

  # get the input and output queues
  input_queue = sqs.get_queue_by_name(QueueName=TASKS_QUEUE_NAME)
  output_queue = sqs.get_queue_by_name(QueueName=RESULTS_QUEUE_NAME)

  send_ack = delete_ack = None

  statsd = StatsClient()
  statsdpipe = statsd.pipeline()

  while True: 
    try: 
      # read message(s) from the input queue
      read_timer = statsdpipe.timer(STATS_PREFIX + 'read_time', rate=STATS_RATE).start()
      messages = input_queue.receive_messages(
        AttributeNames=['ApproximateNumberOfMessages'],
        MaxNumberOfMessages=BATCH_SIZE, 
        WaitTimeSeconds=QUEUE_POLLING_WAIT_TIME, 
        VisibilityTimeout=VISIBILITY_TIMEOUT
      )
    except Exception as e: 
      logging.error('Error receiving messages from queue', exc_info=e)
    finally: 
      if read_timer: read_timer.stop() # read_time

    if messages: 
      response_entries = []
      deletion_entries = []
      n = len(messages)
      statsdpipe.incr(STATS_PREFIX + 'tasks_handled', n, rate=STATS_RATE) 

      exec_timer = statsdpipe.timer(STATS_PREFIX + 'execution_time', rate=STATS_RATE).start()
      for i in range(n): 
        id = messages[i].message_id
        body = messages[i].body
        handle = messages[i].receipt_handle

        logging.debug(f'Processing request message {i+1} of {n} with id [{id}]')

        response_obj = None
        try: 
          request_obj = json.loads(body)
          request_input = request_obj.get('input')
          request_type = request_obj.get('type')

          number = 0
          if (request_type is None) or (request_type in ['decimal', 'dec', 'Decimal']):
            # input is a decimal number
            number = int(request_input)
          else: 
            raise ValueError('Unsupported type parameter is request body')

          factors = factorize(number)

          response_obj = dict(
            output = dict(factors = factors), 
            type = 'Decimal'
          )
        except ValueError as ve:
          logging.error('Invalid JSON in message body', exc_info=ve)
          response_obj = dict(
            error = dict(message = 'Invalid JSON in message body', code = 400)
          )
        except Exception as e:
          logging.error('Unknown error while processing request', exc_info=e)
          response_obj = dict(
            error = dict(message = 'Unknown error while processing request', code = 500)
          )
        response_json = json.dumps(response_obj)

        response_attr = dict(requestMessageId = dict(
          StringValue = id, 
          DataType = 'String'
        ))

        response_entries.append(dict(
          Id = str(i), 
          MessageBody = response_json, 
          MessageAttributes = response_attr
        ))

        deletion_entries.append(dict(
          Id = str(i), 
          ReceiptHandle = handle
        ))
      
      exec_timer.stop() # execution_time

      try: 
        send_timer = statsdpipe.timer(STATS_PREFIX + 'send_time', rate=STATS_RATE).start()
        send_ack = output_queue.send_messages(Entries=response_entries) 
        if send_ack:   
          logging.info(f'Processed and sent {n} response messages to output queue')
      except Exception as e:
        logging.error('Error sending response message', exc_info=e)
      finally: 
        if send_timer: send_timer.stop() # send_time

      try: 
        delete_timer = statsdpipe.timer(STATS_PREFIX + 'delete_time', rate=STATS_RATE).start()
        delete_ack = input_queue.delete_messages(Entries = deletion_entries)
        if delete_ack:   
          logging.debug(f'Deleted {n} messages from input queue')
      except Exception as e:
        logging.error('Error deleting batch messages', exc_info=e)
      finally: 
        if delete_timer: delete_timer.stop()

      statsdpipe.incr(STATS_PREFIX + 'tps', n, rate=STATS_RATE) 
    else: 
      # no messages received from polling
      logging.info(f'No messages received after polling for {QUEUE_POLLING_WAIT_TIME}s. Will retry after {QUEUE_REPOLLING_SLEEP_TIME}s.')
      time.sleep(QUEUE_REPOLLING_SLEEP_TIME)

    statsdpipe.send()

# ---- 
'''
task/request messages must be of the following format: 

{
  "input": "796951910868696778761193", 
  "type": "decimal"
}

response messages will be of the following format: 

{
  "output": {
    "factors": [1, 2, 3]
  }, 
  "type": "decimal", 
  "executionTimeSeconds": 123
}

or 

{
  "error": {
    "message": "Invalid input data", 
    "code": 10
  }
}

following attribute is set in the response message: 
  requestMessageId: "c5ab7e20-bb20-11ea-a37a-acde48001122"

'''

# global variables with default values
LOG_FILENAME = '/var/log/AWSGridWithSQS/worker-main.log'
LOG_LEVEL = 'INFO'
MAX_LOG_FILESIZE = 10*1024*1024 # 10 Mbs
QUEUE_POLLING_WAIT_TIME = 10 # 20 sec is maximum 
QUEUE_REPOLLING_SLEEP_TIME = 0 
VISIBILITY_TIMEOUT = 120 # 2 mins
BATCH_SIZE = 10 # number of messages to read/process in each batch, maximum 10
STATS_PREFIX = 'awsgridwithsqs_worker_'
STATS_RATE = 0.1 # rate = 1/10 as metrics_collection_interval = 10 seconds
TASKS_QUEUE_NAME = 'grid_tasks_queue'
RESULTS_QUEUE_NAME = 'grid_results_queue'


# main
if __name__ == '__main__':
  logHandler = logging.handlers.RotatingFileHandler(LOG_FILENAME, mode='a', maxBytes=MAX_LOG_FILESIZE, backupCount=5)
  logging.basicConfig(handlers=[logHandler], format='%(asctime)s - %(levelname)s - %(message)s', level=LOG_LEVEL)
  signal.signal(signal.SIGINT, exit_handler)
  signal.signal(signal.SIGTERM, exit_handler)
  print('Press Ctrl+C to exit')
  loadParams()
  main()