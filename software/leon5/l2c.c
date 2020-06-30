/*
 * Test for L2-Cache
 *
 * Copyright (c) 2009 Aeroflex Gaisler AB
 *
 */

#include "testmod.h"
#include <l2capi.h>
#include "l2c.h"
#include <stdlib.h>

#if 0
/*
 * l2c_enable(..)
 *
 * regaddr - L2C register base address
 * ften    - Enable FT
 *
 */
int l2c_enable(unsigned int regaddr, unsigned int ften)
{
  unsigned int ctrl;
  struct l2c_regs *l2c;
  
  report_device(0x0104B000);

  l2c = (struct l2c_regs*)regaddr;

  report_subtest(1);
  
  // Flush and enable L2-Cache  
  ctrl = l2c->ctrl;
  if ((ctrl >> 31) == 0) {
    l2c->flush_mem = 5;
    l2c->ctrl = ctrl | (1<<31) | (ften << 30);
  };
  
  return 0;
}

/*
 * l2c_enable_wayflush(..)
 *
 * regaddr - L2C register base address
 *
 */
int l2c_enable_wayflush(unsigned int regaddr, unsigned int ften, int nways)
{
  int i;
  unsigned int ctrl;
  struct l2c_regs *l2c;
  
  report_device(0x0104B000);

  l2c = (struct l2c_regs*)regaddr;

  report_subtest(1);
  
  // Flush and enable L2-Cache  
  ctrl = l2c->ctrl;
  if ((ctrl >> 31) == 0) {
    for (i = 0; i < nways; i++)
       l2c->flush_dir = (i << 4) | 5;
    l2c->ctrl = ctrl | (1<<31) | (ften << 30);
  };
  
  return 0;
}
#endif

static struct l2cregs *regs;
static char *rambase;
static int nways;
/* Number of bytes in way. */
static int waysize;
static int linesize;

/* Write own address inverted to byte offset in way. */
static void mark_offset(int way, int offset)
{
    unsigned int *p;
    char *waybase = rambase + way * waysize;

    p = (unsigned int *) (waybase + offset);
    *p = ~((unsigned int) p);
}

/* Verify that location is cached. Returns 0 iff cached. */
static int lookup_offset(int way, int offset)
{
  struct lookup_res lu;
  unsigned char *p;
  char *waybase = rambase + way * waysize;

  p = (unsigned char *) (waybase + offset);

  /* l2c_lookup expects waysize in KB */
  lu = l2c_lookup((unsigned int) p, waysize/1024, linesize, regs);
  return (0 == lu.valid);
}

/* Verify that location is marked. Returns 0 iff mark is correct. */
static int check_offset(int way, int offset)
{
    unsigned int *p;
    char *waybase = rambase + way * waysize;

    p = (unsigned int *) (waybase + offset);
    if ((*p) == ~((unsigned int) p)) {
      return 0;
    }
    return 1;
}

/* Marking location means setting its data value to address, inverted. */
static int l2c_test001(void)
{
  int way, w, i;

  /* Mark some indexes in all ways. */
  report_subtest(3);
  for (way = 0; way < nways; way++) {
    mark_offset(way, 0);
    mark_offset(way, waysize-4);
    w = waysize;
    do {
      w /= 2;
      mark_offset(way, w-4);
      mark_offset(way, w);
    } while (w > 0x1000);
  }

  /* Verify that these markings exist at the same time. */
  report_subtest(4);
  for (way = 0; way < nways; way++) {
    if (lookup_offset(way, 0)) {
      fail(0x100 + way*0x10 + 0);
    }
    if (lookup_offset(way, waysize - 4)) {
      fail(0x100 + way*0x10 + 1);
    }
    w = waysize; i=2;
    do {
      w /= 2;
      if (lookup_offset(way, w - 4)) {
        fail(0x100 + way*0x10 + i);
      }
      if (lookup_offset(way, w)) {
        fail(0x100 + way*0x10 + i+1);
      }
      i += 2;
    } while (w > 0x1000);
  }

  /* Add one more mark which interferes with one of the earlier. */
  mark_offset(4, 0);

  /* Verify that the new mark is cached and that exactly one of the earlier
  ones has disappeared. According to LRU it should be the first one. */
  report_subtest(5);
  if (!lookup_offset(0, 0)) {
    fail(0x100 + 0x40 + way);
  }
  for (way = 1; way < 5; way++) {
    if (lookup_offset(way, 0)) {
      fail(0x100 + 0x40 + way);
    }
  }

  /* Verify cache/ram value of all values written (marked) so far.*/
  report_subtest(6);
  for (way = 0; way < nways; way++) {
    if (check_offset(way, 0)) {
      fail(0x180 + way*0x10 + 0);
    }
    if (check_offset(way, waysize/2 - 4)) {
      fail(0x180 + way*0x10 + 1);
    }
    if (check_offset(way, waysize/2)) {
      fail(0x180 + way*0x10 + 2);
    }
    if (check_offset(way, waysize - 4)) {
      fail(0x180 + way*0x10 + 3);
    }
  }

  if (check_offset(nways, 0)) {
    fail(0x180 + 4*0x10 + 0);
  }

  /* Disable L2C and flushinvalidate atomically. */
  report_subtest(7);
  l2c_flush_all(1, regs);
  /* And verify RAM values. */
  report_subtest(6);
  for (way = 0; way < nways; way++) {
    if (check_offset(way, 0)) {
      fail(0x1b0 + way*0x10 + 0);
    }
    if (check_offset(way, waysize/2 - 4)) {
      fail(0x1b0 + way*0x10 + 1);
    }
    if (check_offset(way, waysize/2)) {
      fail(0x1b0 + way*0x10 + 2);
    }
    if (check_offset(way, waysize - 4)) {
      fail(0x1b0 + way*0x10 + 3);
    }
  }

  /* And the last "interfering" one */
  if (check_offset(4, 0)) {
    fail(0x1ff);
  }

  l2c_enable(regs);

  return 0;
}

static int l2c_test002(void)
{
  return 0;
}

/*
 * The tests use RAM at 0x01000000..0x01ffffffff, without allocating it using
 * the C standard library. L2-Cache must be enabled before l2c_test is called.
 */
int l2c_test(char *memaddr, struct l2cregs *regaddr)
{
  report_device(0x0104B000);
  rambase = memaddr + 0x01000000;
  regs = (struct l2cregs*)regaddr;

  report_subtest(0);

  nways = l2c_get_ways(regs);
  report_subtest(1);
  waysize = l2c_get_waysize(regs) * 1024;
  linesize = l2c_get_linesize(regs);

  report_subtest(2);
  l2c_test001();

  report_subtest(200);
  l2c_test002();

  return 0;
}
