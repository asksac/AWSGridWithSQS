import logging, time, json
import boto3
from factorizeInteger import factorize

# expects a request as JSON string, returns a tuple with 
# response_json string and execution duration_time in seconds
def handleRequest(request_json):
  response_obj = None
  dt = 0

  try: 
    # record start time
    st = time.time()

    logging.debug('Received message body:', request_json)
    request_obj = json.loads(request_json)

    request_input = request_obj.get('input')
    request_type = request_obj.get('type')

    number = 0

    if (request_type is None) or (request_type in ['decimal', 'dec', 'Decimal']):
      # input is a decimal number
      number = int(request_input)
    else: 
      raise ValueError('Unsupported type parameter is request body')

    factors = factorize(number)

    # execution time duration
    dt = time.time() - st

    response_obj = dict(
      output = dict(factors = factors), 
      type = 'Decimal', 
      executionTimeSeconds = dt
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

  return (json.dumps(response_obj), dt)

# main

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

logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

# Get the service resource
sqs = boto3.resource('sqs')

QUEUE_POLLING_WAIT_TIME = 10 # 20 sec is maximum 
QUEUE_REPOLLING_SLEEP_TIME = 30 
VISIBILITY_TIMEOUT = 120 # 2 mins
BATCH_SIZE = 5 # number of messages to read/process in each batch

# get the input and output queues
input_queue = sqs.get_queue_by_name(QueueName='grid_tasks_queue')
output_queue = sqs.get_queue_by_name(QueueName='grid_results_queue')

st = time.time() # start time
tps = 0 # counter for tps
reset_tps = False

rmt = 0 # receive message time
crmt = 0 # cumulative receive message time

et = 0 # execution time
cet = 0 # cumulative execution time per second

smt = 0 # send message time
csmt = 0 # cumulative send message time

dmt = 0 # delete message time
cdmt = 0 # cumulative delete message time

send_ack = delete_ack = None

while True: 
  try: 
    # read message(s) from the input queue
    rm_st = time.time()
    messages = input_queue.receive_messages(
      MaxNumberOfMessages=BATCH_SIZE, 
      WaitTimeSeconds=QUEUE_POLLING_WAIT_TIME, 
      VisibilityTimeout=VISIBILITY_TIMEOUT
    )
    rm_et = time.time()
    rmt = (rm_et - rm_st)
    crmt += rmt
  except Exception as e: 
    logging.error('Error receiving messages from queue', exc_info=e)

  if messages: 
    response_entries = []
    deletion_entries = []
    n = len(messages)
    for i in range(n): 
      id = messages[i].message_id
      body = messages[i].body
      handle = messages[i].receipt_handle

      logging.info(f'Processing request message {i+1} of {n} with id [{id}]')

      (response_json, et) = handleRequest(body)
      cet += et

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

    try: 
      sm_st = time.time()
      send_ack = output_queue.send_messages(Entries=response_entries) 
      sm_et = time.time()
      smt = (sm_et - sm_st)
      csmt += smt

      if send_ack:   
        logging.info(f'Sent {n} response messages to output queue, executed in {smt}s')

    except Exception as e:
      logging.error('Error sending response message', exc_info=e)

    tps += n

    try: 
      dm_st = time.time()
      delete_ack = input_queue.delete_messages(Entries = deletion_entries)
      dm_et = time.time()
      dmt = (dm_et - dm_st)
      cdmt += dmt
    except Exception as e:
      logging.error('Error deleting batch messages', exc_info=e)
      if delete_ack:   
        logging.info(f'Deleted {n} messages from input queue, executed in {dmt}s')

    logging.info(f'Processed {n} request messages in {cet}s')
  else: # no messages received from polling
    logging.info(f'No messages received after polling for {QUEUE_POLLING_WAIT_TIME}s. Will retry after {QUEUE_REPOLLING_SLEEP_TIME}s.')
    time.sleep(QUEUE_REPOLLING_SLEEP_TIME)
    reset_tps = True

  iter_time = time.time() - st
  if iter_time >= 1.0 or reset_tps: 
    if tps: 
      logging.info(f'Handled {tps} requests per second, with execution stats:')
      logging.info(f'>> Total Iteration Time = {iter_time}')
      logging.info(f'>> Cumulative Execution Time = {cet}')
      logging.info(f'>> Cumulative Receive Message Time = {crmt}')
      logging.info(f'>> Cumulative Send Message Time = {csmt}')
      logging.info(f'>> Cumulative Delete Message Time = {cdmt}')
    st = time.time()
    tps = 0
    reset_tps = False
    cet = crmt = csmt = cdmt = 0.0


