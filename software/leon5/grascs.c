/*
 * Test for GRASCS 
 *
 * Copyright (c) 2008 Gaisler Research AB
 *
 * Requires that the ascs_slave model is connected in the testbench
 *
 * Tests:
 * 1 - Write one word, read one word
*/

#include "testmod.h"

/* Command register */
#define GRASCS_CMD_RESET       (1 << 0)
#define GRASCS_CMD_STARTSTOP   (1 << 1)
#define GRASCS_CMD_ESTARTSTOP  (1 << 2)
#define GRASCS_CMD_SENDTM      (1 << 3)
#define GRASCS_CMD_ETRCTRL     (7 << 4)
#define GRASCS_CMD_ETRCTRL_P   4
#define GRASCS_CMD_SLAVESEL    (15 << 8)
#define GRASCS_CMD_SLAVESEL_P  8
#define GRASCS_CMD_TCDONE      (1 << 12)
#define GRASCS_CMD_TMDONE      (1 << 13)
#define GRASCS_CMD_US1         (255 << 16)
#define GRASCS_CMD_US1_P       16
#define GRASCS_CMD_US1C        (1 << 24)
#define GRASCS_CMD_OEN         (1 << 31)


/* Status register */
#define GRASCS_STS_RUNNING     (1 << 0)
#define GRASCS_STS_ERUNNING    (1 << 1)
#define GRASCS_STS_TCDONE      (1 << 4)
#define GRASCS_STS_TMDONE      (1 << 5)
#define GRASCS_STS_DBITS_P     8
#define GRASCS_STS_NSLAVES_P   13
#define GRASCS_STS_USCONF_P    18
#define GRASCS_STS_TMCONF_P    19


#define PAYLOAD 0xaabbccdd

struct ascsregs {
  volatile unsigned int cmd;
  volatile unsigned int clk;
  volatile unsigned int sts;
  volatile unsigned int tcd;
  volatile unsigned int tmd;
};


int grascs_test(int addr)
{

  int mask;
  struct ascsregs *regs;

  report_device(0x01043000);

  regs = (struct ascsregs*)addr;

  report_subtest(1);

  regs->cmd |= GRASCS_CMD_STARTSTOP | GRASCS_CMD_OEN;

  switch ((regs->sts >> GRASCS_STS_DBITS_P) & 0x1F) {
  case 31: mask = ~0; break;
  case 15: mask = 0xffff; break;
  default: mask = 0xff; break;
  }

  regs->tcd = PAYLOAD;

  while (!(regs->sts & GRASCS_STS_TCDONE))
    ;

  regs->sts |= GRASCS_STS_TCDONE;

  if ((regs->sts & 0xff) != GRASCS_STS_RUNNING)
    fail(1);

  regs->cmd |= GRASCS_CMD_SENDTM;

  while (!(regs->sts & GRASCS_STS_TMDONE))
    ;

  if (regs->tmd != (PAYLOAD & mask))
    fail(2);

  regs->sts |= GRASCS_STS_TMDONE;

  if ((regs->sts & 0xff) != GRASCS_STS_RUNNING)
    fail(3);

  regs->cmd = 0;

  return 0;
}
