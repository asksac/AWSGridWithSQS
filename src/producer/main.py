import logging, time, json, random
import boto3
from primeNumbers import generateLargePrime

# main

logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

# Get the service resource
sqs = boto3.resource('sqs')

QUEUE_WAIT_TIME = 20 # 120 # 2 mins
VISIBILITY_TIMEOUT = 120 # 2 mins

MESSAGES_PER_SECOND = 10

# get the tasks queue
tasks_queue = sqs.get_queue_by_name(QueueName='grid_tasks_queue')

while True: 
  st = time.time()
  dt = 0
  i = 0

  while i < MESSAGES_PER_SECOND: 
    #bits = random.randint(25, 45) 
    bits = random.randint(5, 15) 
    number = generateLargePrime(bits)

    req_obj = dict(input = number, type = 'Decimal')
    req_body = json.dumps(req_obj)

    try: 
      ack = tasks_queue.send_message(MessageBody=req_body) 
      if ack:   
        logging.info(f'Sent task with input [{number}] and message id [{ack["MessageId"]}]')

    except Error as e:
      logging.error('Error sending task message', exc_info=e)

    dt = time.time() - st
    if dt >= 1.0: 
      # it is >= 1 second
      logging.error('Time exceeded before reaching MESSAGES_PER_SECOND')
      break
    else: 
      i += 1

  if (dt < 1.0): 
    time.sleep(1.0 - dt)
    

  