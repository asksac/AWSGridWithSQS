import time
import sys, os
#sys.path.append('../')
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from producer.primeNumbers import *
from worker.factorizeInteger import * 

bits = 10 # default 

if len(sys.argv) > 1:
  bits = int(sys.argv[1])

st = time.time()
p1 = generateLargePrime(bits)
et = time.time()
print(f'p1 = {p1} ({et - st} s)')

st = time.time()
p2 = generateLargePrime(bits)
et = time.time()
print(f'p2 = {p2} ({et - st} s)')

pp = p1 * p2
print(f'product of primes p1 * p2: {pp}')

st = time.time()
f = factorize(pp)
et = time.time()
print(f'factors of p1 * p2 are: {f} ({et - st} s)')




