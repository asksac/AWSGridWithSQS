import logging, time, json, random
import boto3
from primeNumbers import generateLargePrime
from statsd import StatsClient

def main():
  # Get the service resource
  sqs = boto3.resource('sqs')

  # get the tasks queue
  tasks_queue = sqs.get_queue_by_name(QueueName='grid_tasks_queue')

  statsd = StatsClient()
  statsdpipe = statsd.pipeline()

  while True: 
    exec_timer = statsdpipe.timer(STATSD_PREFIX + 'exec_time', rate=STATSD_RATE).start()
    queue_entries = []

    for i in range (0, 10): 
      #bits = random.randint(15, 25) 
      bits = random.randint(20, 35) 
      number = generateLargePrime(bits)

      req_obj = dict(input = number, type = 'Decimal')
      req_json = json.dumps(req_obj)

      queue_entries.append(dict(
        Id = str(i), 
        MessageBody = req_json
      ))

    exec_timer.stop()

    # send the batch of task messages
    send_timer = statsdpipe.timer(STATSD_PREFIX + 'send_msg_time', rate=STATSD_RATE).start()
    try: 
      ack = tasks_queue.send_messages(Entries=queue_entries) 
      n = len(queue_entries)
      if ack: 
        statsdpipe.incr(STATSD_PREFIX + 'throughput', n, rate=STATSD_RATE) 
        logging.debug(f'Sent a batch of {n} task messages')
    except Error as e:
      logging.error('Error sending task messages', exc_info=e)

    send_timer.stop()

    statsdpipe.send()

# main
LOG_FILENAME = '/var/log/AWSGridWithSQS/producer-main.log'
logging.basicConfig(filename=LOG_FILENAME, format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

STATSD_PREFIX = 'awsgridwithsqs_producer_'
STATSD_RATE = 1 # rate = 1/10 as metrics_collection_interval = 10 seconds

main()      

logger.shutdown()