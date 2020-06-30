#include <stdio.h>
#include <stdlib.h>
#include "coremark.h"
//#include "platform.h"
#include "core_portme.h"
#include "encoding.h"

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif

volatile ee_s32 seed4_volatile=ITERATIONS;
volatile ee_s32 seed5_volatile=0;

static CORE_TICKS t0, t1;

uint64_t get_timer_value()
{
#if __riscv_xlen == 32
  while (1) {
    uint32_t hi = read_csr(mcycleh);
    uint32_t lo = read_csr(mcycle);
    if (hi == read_csr(mcycleh))
      return ((uint64_t)hi << 32) | lo;
  }
#else
  return read_csr(mcycle);
#endif
}

static unsigned long get_cpu_freq()
{
  return 100000000; //65000000;
}

unsigned long get_timer_freq()
{
  return get_cpu_freq();
}

void start_time(void)
{
  t0 = get_timer_value();
}

void stop_time(void)
{
  t1 = get_timer_value();
}

CORE_TICKS get_time(void)
{
#if !defined(NOSTAT)
  return t1 - t0;
#else
  return 10 * get_timer_freq();
#endif
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
  // scale timer down to avoid uint64_t -> double conversion in RV32
  int scale = 256;
  uint32_t delta = ticks / scale;
  uint32_t freq = get_timer_freq() / scale;
  return delta / freq;
}
