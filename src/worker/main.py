import os, signal, sys
import logging, logging.handlers
import json, random, re, time
import boto3
from factorizeInteger import factorize
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

  path = '/' + params['AWS_ENV'] + '/AWSGridWithSQS/worker/'
  ssm_params = ssm.get_parameters_by_path(Path = path)

  if ssm_params and ssm_params['Parameters']: 
    for p in ssm_params['Parameters']: 
      n = p['Name'][len(path):] # strip out path prefix
      v = p['Value']
      if (n == 'log_filename'):
        params['LOG_FILENAME'] = v
      elif (n == 'log_level'):
        params['LOG_LEVEL'] = v
      elif (n == 'queue_polling_wait_time'):
        params['QUEUE_POLLING_WAIT_TIME'] = int(v)
      elif (n == 'queue_repolling_sleep_time'):
        params['QUEUE_REPOLLING_SLEEP_TIME'] = int(v)
      elif (n == 'visibility_timeout'):
        params['VISIBILITY_TIMEOUT'] = int(v)
      elif (n == 'batch_size'):
        params['BATCH_SIZE'] = int(v)
      elif (n == 'stats_prefix'):
        params['STATS_PREFIX'] = v
      elif (n == 'stats_rate'):
        params['STATS_RATE'] = float(v)
      elif (n == 'tasks_queue_name'):
        params['TASKS_QUEUE_NAME'] = v
      elif (n == 'results_queue_name'):
        params['RESULTS_QUEUE_NAME'] = v
  return params


# polls an SQS queue continuously and processes requests 
def main(params): 
  # Get the service resource
  sqs = boto3.resource('sqs')

  # get the input and output queues
  input_queue = sqs.get_queue_by_name(QueueName=params['TASKS_QUEUE_NAME'])
  output_queue = sqs.get_queue_by_name(QueueName=params['RESULTS_QUEUE_NAME'])

  send_ack = delete_ack = None

  statsd = StatsClient()
  statsdpipe = statsd.pipeline()

  sprefix = params['STATS_PREFIX']
  srate = params['STATS_RATE']

  while True: 
    try: 
      # read message(s) from the input queue
      read_timer = statsdpipe.timer(sprefix + 'read_time', rate=srate).start()
      messages = input_queue.receive_messages(
        AttributeNames=['ApproximateNumberOfMessages'],
        MaxNumberOfMessages=params['BATCH_SIZE'], 
        WaitTimeSeconds=params['QUEUE_POLLING_WAIT_TIME'], 
        VisibilityTimeout=params['VISIBILITY_TIMEOUT']
      )
    except Exception as e: 
      logging.error('Error receiving messages from queue', exc_info=e)
    finally: 
      if read_timer: read_timer.stop() # read_time

    if messages: 
      response_entries = []
      deletion_entries = []
      n = len(messages)
      statsdpipe.incr(sprefix + 'tasks_handled', n, rate=srate) 

      exec_timer = statsdpipe.timer(sprefix + 'execution_time', rate=srate).start()
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
        send_timer = statsdpipe.timer(sprefix + 'send_time', rate=srate).start()
        send_ack = output_queue.send_messages(Entries=response_entries) 
        if send_ack:   
          logging.info(f'Processed and sent {n} response messages to output queue')
      except Exception as e:
        logging.error('Error sending response message', exc_info=e)
      finally: 
        if send_timer: send_timer.stop() # send_time

      try: 
        delete_timer = statsdpipe.timer(sprefix + 'delete_time', rate=srate).start()
        delete_ack = input_queue.delete_messages(Entries = deletion_entries)
        if delete_ack:   
          logging.debug(f'Deleted {n} messages from input queue')
      except Exception as e:
        logging.error('Error deleting batch messages', exc_info=e)
      finally: 
        if delete_timer: delete_timer.stop()

      statsdpipe.incr(sprefix + 'tps', n, rate=srate) 
    else: 
      # no messages received from polling
      logging.debug(f"No messages received after polling for {params['QUEUE_POLLING_WAIT_TIME']}s. Will retry after {params['QUEUE_REPOLLING_SLEEP_TIME']}s.")
      time.sleep(params['QUEUE_REPOLLING_SLEEP_TIME'])

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
  "type": "decimal" 
}

following attribute is set in response messages: 
  requestMessageId: "c5ab7e20-bb20-11ea-a37a-acde48001122"

response errors will be of the following format: 
{
  "error": {
    "message": "Invalid input data", 
    "code": 10
  }
}

'''

# define default parameter values
defaults = dict(
  AWS_ENV                     = 'dev', 
  LOG_FILENAME                = '/var/log/AWSGridWithSQS/worker-main.log', 
  LOG_LEVEL                   = 'INFO', 
  MAX_LOG_FILESIZE            = 10*1024*1024, # 10 Mbs
  QUEUE_POLLING_WAIT_TIME     = 10, # 20 sec is maximum 
  QUEUE_REPOLLING_SLEEP_TIME  = 0,  
  VISIBILITY_TIMEOUT          = 120, # 2 mins
  BATCH_SIZE                  = 10, # number of messages to read/process in each batch, maximum 10
  STATS_PREFIX                = 'awsgridwithsqs_worker_', 
  STATS_RATE                  = 1, 
  TASKS_QUEUE_NAME            = 'grid_tasks_queue', 
  RESULTS_QUEUE_NAME          = 'grid_results_queue', 
)


# main
if __name__ == '__main__':
  params = loadParams(defaults)
  logHandler = logging.handlers.RotatingFileHandler(params['LOG_FILENAME'], mode = 'a', maxBytes = params['MAX_LOG_FILESIZE'], backupCount = 5)
  logging.basicConfig(handlers = [logHandler], format = '%(asctime)s - %(levelname)s - %(message)s', level = params['LOG_LEVEL'])
  signal.signal(signal.SIGINT, exit_handler)
  signal.signal(signal.SIGTERM, exit_handler)
  print('Press Ctrl+C to exit')
  main(params)