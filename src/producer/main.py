import logging, time, json, random
import boto3
from primeNumbers import generateLargePrime
from statsd import StatsClient

def main():
  # Get the service resource
  sqs = boto3.resource('sqs')

  # get the tasks queue
  tasks_queue = sqs.get_queue_by_name(QueueName='grid_tasks_queue')

  while True: 
    statsdpipe = statsd.pipeline()
    st = time.time()
    dt = 0
    i = 1
    queue_entries = []
    csmt = 0
    cet = 0

    while i <= MESSAGES_PER_SECOND: 
      est = time.time()
      #bits = random.randint(15, 25) 
      bits = random.randint(20, 35) 
      number = generateLargePrime(bits)
      cet += time.time() - est

      req_obj = dict(input = number, type = 'Decimal')
      req_json = json.dumps(req_obj)

      queue_entries.append(dict(
        Id = str(i), 
        MessageBody = req_json
      ))

      dt = time.time() - st

      if (i % 10 == 0) or (i >= MESSAGES_PER_SECOND) or (dt >= 1.0):
        # time to send a batch of messages
        try: 
          sm_st = time.time()
          ack = tasks_queue.send_messages(Entries=queue_entries) 
          sm_et = time.time()
          smt = sm_et - sm_st 
          csmt += smt
          if ack: 
            logging.debug(f'Sent a batch of {len(queue_entries)} task messages with {smt}s send message latency')
          queue_entries = []
        except Error as e:
          logging.error('Error sending task messages', exc_info=e)

      dt = time.time() - st

      if (i >= MESSAGES_PER_SECOND) or (dt >= 1.0): 
        # end of inner while loop
        logging.info(f'Delivered {i} of {MESSAGES_PER_SECOND} messages in {dt}s, and {csmt}s total send message time')
        statsdpipe.gauge(STATS_PREFIX + '.producer.tps', i)
        statsdpipe.gauge(STATS_PREFIX + '.producer.mps', MESSAGES_PER_SECOND)
        statsdpipe.gauge(STATS_PREFIX + '.producer.cet', cet)
        statsdpipe.gauge(STATS_PREFIX + '.producer.csmt', csmt)
        statsdpipe.send()
        break
      else: 
        i += 1

    if dt <= 1.0: 
      time.sleep(1.0 - dt)

# main
LOG_FILENAME = '/var/log/AWSGridWithSQS/producer-main.log'
logging.basicConfig(filename=LOG_FILENAME, format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

VISIBILITY_TIMEOUT = 120 # 2 mins
MESSAGES_PER_SECOND = 600
STATS_PREFIX = 'awsgridwithsqs'

statsd = StatsClient()

main()      

logger.shutdown()