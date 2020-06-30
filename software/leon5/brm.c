#include <stdlib.h>
#include <string.h>

#define BRM_ADDR 0xfff00000
#define BRM_IRQ  4

struct irq_reg {
  volatile unsigned int level;
  volatile unsigned int pending;
  volatile unsigned int force;
  volatile unsigned int clear;
  volatile unsigned int mpstat;
  volatile unsigned int dummy[11];
  volatile unsigned int mask;
};

struct brm_regs {

  /* BRM registers (16 bit) */
  volatile unsigned int ctrl;            /* 0x00 */
  volatile unsigned int oper;            /* 0x04 */
  volatile unsigned int cur_cmd;         /* 0x08 */
  volatile unsigned int imask;           /* 0x0C */
  volatile unsigned int ipend;           /* 0x10 */
  volatile unsigned int ipoint;          /* 0x14 */
  volatile unsigned int bit_reg;         /* 0x18 */
  volatile unsigned int ttag;            /* 0x1C */
  volatile unsigned int dpoint;          /* 0x20 */
  volatile unsigned int sw;              /* 0x24 */
  volatile unsigned int initcount;       /* 0x28 */
  volatile unsigned int mcpoint;         /* 0x2C */
  volatile unsigned int mdpoint;         /* 0x30 */
  volatile unsigned int mbc;             /* 0x34 */
  volatile unsigned int mfilta;          /* 0x38 */
  volatile unsigned int mfiltb;          /* 0x3C */
  volatile unsigned int rt_cmd_leg[16];  /* 0x40-0x7C */
  volatile unsigned int enhanced;        /* 0x80 */

  volatile unsigned int dummy[31];

  /* wrapper registers (32 bit) */
  volatile unsigned int w_ctrl;          /* 0x100 */
  volatile unsigned int w_irqctrl;       /* 0x104 */
  volatile unsigned int w_ahbaddr;       /* 0x108 */
};


static struct irq_reg *irq = (struct irq_reg *) 0x80000200;
static struct brm_regs *bc = (struct brm_regs *) BRM_ADDR;

volatile unsigned short *bcmem = NULL;
volatile unsigned int *bcmemi = NULL;

volatile int done=0;
volatile int bci=0;

extern void *catch_interrupt(void func(), int irq);

void irq_handler(int irqn)
{
  int tmp=0;

  irq->clear = (1 << irqn);	
  bci++;

  tmp = bc->ipend;
  
  if (tmp & 0x0020) {
      done = 1;
  }


}

error(char *message, int *count) {
  puts(message);
  *count++;
  return;
}

static char *almalloc(int sz)
{
  char *tmp;  
  tmp = malloc(2*sz);
  tmp = (char *) ( ( (int)tmp+sz ) & ~(sz-1));
  return(tmp);
}

/* creates a BC command block */
void create_cmd(unsigned short *addr, unsigned short op, unsigned short cond, 
	unsigned short rtrt, unsigned short cw1, unsigned short cw2, 
	unsigned short dp, unsigned short bra, unsigned short time, int bus) {
  memset(addr, 0, sizeof(addr));
  addr[0] = (op << 12) | (bus << 9) | (rtrt << 8) | (cond << 1);
  addr[1] = cw1;
  addr[2] = cw2;
  addr[3] = dp;
  addr[6] = bra;
  addr[7] = time;
}

/* Create BC to RT command block */
void bcrt(unsigned short *addr, unsigned short dp, unsigned short rtaddr, unsigned short sa, 
	unsigned short wc, int bus) {
  unsigned short cw = (rtaddr << 11) | (0 << 10) | (sa << 5) | (wc & 0x1F);
  create_cmd(addr, 4, 0, 0, cw, 0, dp, 0, 0, bus);
}

/* Create RT to BC command block */
void rtbc(unsigned short *addr, unsigned short dp, unsigned short rtaddr, 
	unsigned short sa, unsigned short wc, int bus) {
  unsigned short cw = (rtaddr << 11) | (1 << 10) | (sa << 5) | (wc & 0x1F);
  create_cmd(addr, 4, 0, 0, cw, 0, dp, 0, 0, bus);
}

/*
asm (".data\n"
     ".global bcmemx\n"
     "bcmemx: .space 262144/4, 0\n"
     ".text\n"
     );
*/


int brm_test(int addr, int nirq)
{
  done = 0; 
  int i, j, k;
  int ec = 0;
  int temp;
  volatile unsigned int bcmemx[64*1024];


  report_device(0x01072000);
  bc = (struct brm_regs *) addr;
  bcmemi = (int *) ((int)bcmemx & 0xfffe0000);
  bcmem = (unsigned short *) bcmemi;

  if (bcmem == NULL) {
    puts("Error allocating memory");
    exit(1);
  }

  irq->clear = 0xffff;
  irq->level = 0;

  catch_interrupt(irq_handler, nirq);
  enable_irq(nirq);

  bc->ctrl = 0x0010;     /* enable bcast  */
  bc->oper = 0x0000;     /* configure as BC */
  bc->imask = 0xffff;
  bc->ipoint = 0;        /* irq log list, not used */
  bc->dpoint = 0;        /* command block pointer (within 64x16b block) */
  bc->enhanced = 0x0003; /* freq = 24 */
  bc->w_ctrl = 1;
  bc->w_irqctrl = 0;
  bc->w_ahbaddr = (unsigned int) bcmem;
 
  /* setting up data to send */
  for (i = 0; i < 32; i++) {
    bcmem[0x8000 + i] = (unsigned short) i;
  }
  
  for (i = 0; i < 2; i++) {

    for (j = 0; j < 3; j++) { 

      bcrt((unsigned short *)&bcmem[(i*3+j)*8], 0x8000, 1, i+1, 2, j&1); /* 32 words per message */

    }

  }

  bcmem[2*8*3] = 0x0000;   /* End of list command */
 
  /* start operation */
  bc->ctrl |= 0x8000;
 
  while (!done) {
    ;
  }


  return 0;
  
}
