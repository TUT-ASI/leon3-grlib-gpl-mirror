#include <stdlib.h>
#include "grspwtdp.h"
#include "grspwtdp-regs.h"
#include "gpio.h"
#include "testmod.h"

volatile struct grspwtdp_regs *r;
volatile struct grgpio_apb *gpio;
 
static const uint32_t ISTS_EDI0 = 1<<6;
static const uint32_t STAT_EDS0 = 1<<24;

/* Generate interrupt 16 by using GPIO */
static void gen_int(void)
{
  /* Setup IO 0 for rising edge triggering. */
  gpio->irqmask &= ~1;
  gpio->irqpol |= 1;
  gpio->irqedge |= 1;
  gpio->irqmap[0] &= ~0x0f000000;
  gpio->iodir |= 1;
  gpio->iooutput &= ~1;

  /* Enable interrupt for IO 0. */
  gpio->irqmask |= 1;
  gpio->iooutput |= 1;
  gpio->iooutput &= ~1;
}

static int hw_reset(void)
{
        int i = 1000;

        r->conf[0] = 1;

        while ((r->conf[0] & 1) && i > 0) {
                i--;
        }

        r->ists = 0xffffffff;
        /* Configure Frequency Synthesizer value corresponding to 
           System Frequency (to start CUC time) */
        /* The value provided below is for 250 MHz */
        r->conf[1] = 72057594;

        return i ? 0 : -1;
}

static int parse_precision(unsigned short preamble, int *coarse, int *fine)
{
	int coarse_presision, fine_presision;

	if (preamble & 0x80) {
		return -1;
	}
	if (!((preamble & 0x7000) == 0x2000 || (preamble & 0x7000) == 0x1000)) {
		return -1;
	}
	/*
	coarse_presision = 32;
	fine_presision = 24;
	*/
	coarse_presision = ((preamble >> 10) & 0x3) + 1;
	if (preamble & 0x80)
		coarse_presision += (preamble >> 5) & 0x3;
	fine_presision = (preamble >> 8) & 0x3;
	if (preamble & 0x80)
		fine_presision += (preamble >> 2) & 0x7;
	if (coarse)
		*coarse = coarse_presision;
	if (fine)
		*fine = fine_presision;
	return 0;
}

/* Read the ET and parse the preamble pointed to by ctrl, and then put
 * only the time (not the preamble) into memory pointed to by time argument
 */
static int read_et_all(volatile uint32_t *ctrl, unsigned char *time)
{
	unsigned int sample[6];
	int i, ccnt, fcnt;
        unsigned short preamble;

        for (i = 0; i < sizeof(sample)/sizeof(sample[0]); i++) {
	        sample[i] = ctrl[i];
        }

        preamble = sample[0] & 0xffff;
	if (parse_precision(preamble, &ccnt, &fcnt))
		return -1;

	for (i=0; i < ccnt+fcnt; i++)
		time[i] = ((unsigned char *)sample)[4+i];
	return 0;
}

/* Compare two Elapsed Time codes:
 * returns -1 if b < a
 * returns 1 if b > a
 * returns 0 if b == a
 */
static int cmp_et(
	unsigned short preamble,
	unsigned char *a,
	unsigned char *b)
{
	int i, ccnt, fcnt;

	if (parse_precision(preamble, &ccnt, &fcnt))
		return -1;

	for (i = 0; i < ccnt+fcnt; i++) {
		if (b[i] < a[i])
			return -1;
		else if (b[i] > a[i])
			return 1;
	}

	return 0;
}

/*
static int report_time(unsigned short preamble, unsigned char *t)
{
  int i, ccnt, fcnt;

  if (parse_precision(preamble, &ccnt, &fcnt)) {
    return -1;
  }
  
  for (i=0; i < ccnt+fcnt; i++) {
    report_subtest(t[i]);
  }
  return 0;
}
*/

/* Latch datation at four points in time using external event and four datation
 * register sets. Also read out the local time at inbetween. Compare all values
 * to assert chronological order. */
static int test001(void)
{
  static unsigned char latched[4][10];
  static unsigned char local[5][10];

  int i;
  unsigned short preamble;
  volatile uint32_t dummy;

  report_subtest(1);
  preamble = r->dat_ctrl & 0xffff;
  for (i = 0; i < 4; i++) {
    /* Local timer read (datation). */
    read_et_all(&r->dat_ctrl, &local[i][0]);

    r->ists = 0xffffffff;
    /* FIXME: Enabling interrupt should not be necessary for activating
     * interrupt status bits, but it is! */
    r->ien = ISTS_EDI0<<i;
    r->edmask[i] = 1<<16;
    if (r->edmask[i] != 1<<16) { fail(1000+i); }

    if ((r->ists & ISTS_EDI0<<i)) { fail (1020+i); }
    gen_int();
    if (r->edmask[i]) { fail(1030); }
    if (!(r->ists & ISTS_EDI0<<i)) { fail (1040+i); }
    if (!(r->stat[0] & STAT_EDS0<<i)) { fail (1060+i); }

    /* Test if read of offset 0 clears status bit. It shouldn't. */
    dummy = r->ed[i].et[0];
    if (!(r->stat[0] & STAT_EDS0<<i)) { fail (1080+i); }

    read_et_all(&r->ed[i].ctrl, &latched[i][0]);

    /* returns -1 if latched[0] < local[0] */
    if (cmp_et(preamble, &local[i][0], &latched[i][0]) < 0) {
      fail(1100+i);
    }
    if ((r->stat[0] & STAT_EDS0<<i)) { fail (1120+i); }
  }
  read_et_all(&r->dat_ctrl, &local[i][0]);

  if (cmp_et(preamble, &latched[0][0], &local[1][0]) <= 0) {
    fail(1140);
  }
  if (cmp_et(preamble, &latched[i-1][0], &local[i][0]) <= 0) {
    fail(1150);
  }

  return 0;
}

/* Multiple latching of same register, same external event. */
static int test002(void)
{
  static unsigned char latched[8][10];
  static unsigned char latchedt[10];
  unsigned short preamble;
  volatile uint32_t dummy;
  int i;

  report_subtest(2);

  preamble = r->ed[3].ctrl & 0xffff;
  for (i = 0; i < 8; i++) {
    r->ists = 0xffffffff;
    /* FIXME: Enabling interrupt should not be necessary for activating
     * interrupt status bits, but it is! */
    r->ien = ISTS_EDI0<<3;

    r->edmask[3] = 1<<16;
    if (r->edmask[3] != 1<<16) { fail(1); }

    if ((r->ists & ISTS_EDI0<<3)) { fail (2); }
    gen_int();
    if (r->edmask[3]) { fail(3); }
    if (!(r->ists & ISTS_EDI0<<3)) { fail (4); }
    if (!(r->stat[0] & STAT_EDS0<<3)) { fail (5); }

    /* Test if read of offset 0 clears status bit. It shouldn't. */
    dummy = r->ed[3].et[0];
    if (!(r->stat[0] & STAT_EDS0<<3)) { fail (6); }

    read_et_all(&r->ed[3].ctrl, latched[i]);
    if ((r->stat[0] & STAT_EDS0<<3)) { fail (7); }

    /* Verify that external datation has not changed since last read. */
    read_et_all(&r->ed[3].ctrl, latchedt);
    if (cmp_et(preamble, latched[i], latchedt) != 0) {
      fail(20+i);
    }
  }

  for (i = 0; i < 7; i++) {
    if (cmp_et(preamble, latched[i], latched[i+1]) < 0) {
      fail(10+i);
    }
  }

  return 0;
}

int grspwtdp_test(void *spwtdpbase, void *gpiobase)
{
  if (NULL == spwtdpbase || NULL == gpiobase) {
    fail(1);
  }

  report_device(DEVICE_GRSPWTDP);
  r = spwtdpbase;
  gpio = gpiobase;

  if (0 != hw_reset()) {
    fail(0);
  }
  test001();
  test002();

  return 0;
}
