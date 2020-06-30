/*
 * Test for GRSLINK 
 *
 * Copyright (c) 2008 Gaisler Research AB
 * Copyright (c) 2009 Aeroflex Gaisler AB
 *
 * Requires that the slnkstslv model is connected in the testbench
 *
 * Tests:
 * 1 - Reads one word from slave model
 * 2 - Perform SEQUENCE of length 2
 * 
 */

#include "testmod.h"
#include <malloc.h>

/* Control register */
#define SLINK_C_SLEN_P 16
#define SLINK_C_SCN_P  4
#define SLINK_C_PAR   (1 << 3)
#define SLINK_C_AS    (1 << 2)
#define SLINK_C_SE    (1 << 1)
#define SLINK_C_SLE   (1 << 0)

/* Status register fields */
#define SLINK_S_SI_P 16
#define SLINK_S_PERR (1 << 7)
#define SLINK_S_AERR (1 << 6)
#define SLINK_S_ROV  (1 << 5)
#define SLINK_S_RNE  (1 << 4)
#define SLINK_S_TNF  (1 << 3)
#define SLINK_S_SC   (1 << 2)
#define SLINK_S_SA   (1 << 1)
#define SLINK_S_SRX  (1 << 0)

/* Bits and fields in SLINK transmit word */
#define SLINK_RW     (1 << 23)
#define SLINK_SLV_P  21
#define SLINK_CHAN_P 16

#define SLINK_SEQ_CHAN 0x6

#define SLINK_PL1 0x5a
#define SLINK_PL2 0xf0
        
#define EXPECTED_SEQ_O ((1 << SLINK_SLV_P) | (SLINK_SEQ_CHAN << SLINK_CHAN_P) | SLINK_PL1)
#define EXPECTED_SEQ_1 ((1 << SLINK_SLV_P) | (SLINK_SEQ_CHAN << SLINK_CHAN_P) | SLINK_PL2)

struct slinkregs {
  volatile unsigned int clockscale;
  volatile unsigned int ctrl;
  volatile unsigned int nullwrd;
  volatile unsigned int sts;
  volatile unsigned int msk;
  volatile unsigned int abase;
  volatile unsigned int bbase;
  volatile unsigned int td;
  volatile unsigned int rd;
};


int grslink_test(int addr)
{

  struct slinkregs *regs;
  volatile unsigned int *a, *b;

  report_device(0x0102f000);

  regs = (struct slinkregs*)addr;

  regs->clockscale = 0x00020002;
  regs->nullwrd = 0;
  regs->msk = 0;
  regs->ctrl |= SLINK_C_SLE;
  

  /* Read one word */
  report_subtest(1);
  
  if (regs->sts != SLINK_S_TNF)
    fail(0);

  regs->td = SLINK_RW | (1 << SLINK_SLV_P) | SLINK_PL1;

  while (!(regs->sts & SLINK_S_RNE))
    ;

  if (regs->sts != (SLINK_S_RNE | SLINK_S_TNF | SLINK_S_SRX))
    fail(1);
  
  if (regs->rd != ((1 << SLINK_SLV_P) | (3 << SLINK_CHAN_P) | SLINK_PL1))
    fail(2);

  if (regs->sts != (SLINK_S_TNF | SLINK_S_SRX))
    fail(3);

  regs->sts = regs->sts;

  if (regs->sts != SLINK_S_TNF)
    fail(4);

  /* Perform SEQUENCE of length 2 */
  report_subtest(2);
  
  a = calloc(2, sizeof(int));
  b = calloc(2, sizeof(int));

  *a = (SLINK_RW | (1 << SLINK_SLV_P) | (SLINK_SEQ_CHAN << SLINK_CHAN_P) | 
	SLINK_PL1);
  *(a+1) = (SLINK_RW | (1 << SLINK_SLV_P) | (SLINK_SEQ_CHAN << SLINK_CHAN_P) | 
	    SLINK_PL2);

  regs->abase = (int)a;
  regs->bbase = (int)b;

  regs->ctrl |= ((1 << SLINK_C_SLEN_P) | (SLINK_SEQ_CHAN << SLINK_C_SCN_P) | 
		 SLINK_C_SE);

  while (!(regs->sts & SLINK_S_SC) && 
	 !((regs->sts & ~(SLINK_S_SC | SLINK_S_TNF)) & 0xFF))
    ;

  if (!(regs->sts & SLINK_S_SC))
    fail(0);

  if ((regs->sts >> 16) != 2)
    fail(1);

  if (b[0] != EXPECTED_SEQ_O)
    fail(2);

  if (b[1] != EXPECTED_SEQ_1)
    fail(3);
  
  regs->ctrl = 0;
  
  free((int*)a);
  free((int*)b);

  return 0;
}
