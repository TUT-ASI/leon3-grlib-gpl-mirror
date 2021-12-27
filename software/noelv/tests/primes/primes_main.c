/*
 * derived from rv8-io: https://github.com/rv8-io/rv8-bench/blob/master/src/primes.c
 * 
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

#include "util.h"

#define test(p) (primes[p >> 6] & 1 << (p & 0x3f))
#define set(p) (primes[p >> 6] |= 1 << (p & 0x3f))
#define is_prime(p) !test(p)

/***************/
/* Timing      */
/***************/

#define HZ 100000000

uint64_t Begin_Time, End_Time, User_Time;
uint64_t Primes_Per_Second;

int main()
{
#if 0
  int iterations = 33333;
#else
  int iterations = 10;
#endif
  int limit = 33333;
  size_t primes_size = ((limit >> 6) + 1) * sizeof(uint64_t);

  // Static Memory
  uint64_t static_memblk [primes_size];
  uint64_t *primes = (uint64_t*)static_memblk;
	
  int64_t p = 2, sqrt_limit = (int64_t)sqrt(limit);

  /***************/
  /* Start timer */
  /***************/

  setStats(1);
#if 0
  Begin_Time = read_csr(mcycle);
#else
  Begin_Time = 0;
#endif

  /***************/
  /* Main Loop   */
  /***************/

  for (int j = 1; j <= iterations; j++) {

    limit = j;

    while (p <= limit >> 1) {
      for (int64_t n = 2 * p; n <= limit; n += p) if (!test(n)) set(n);
      while (++p <= sqrt_limit && test(p));
    }

    for (int i = j; i > 0; i--) {
      if (is_prime(i)) {
	break;
      }
    }
  }

  /**************/
  /* Stop timer */
  /**************/

#if 0
  End_Time = read_csr(mcycle);
#else
  End_Time = 1;
#endif
  setStats(0);

  User_Time = End_Time - Begin_Time;
  Primes_Per_Second = (HZ * iterations) / User_Time;
  printf("Primes iterations:                      %d\n", iterations);
  printf("Primes per Second:                      %ld Primes/sec\n", Primes_Per_Second);

  return 0;

 };
