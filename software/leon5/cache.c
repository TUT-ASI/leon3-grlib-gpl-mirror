#include <stdio.h>
#include "testmod.h"
#include "leon3.h"

#define CCTRL_IFP (1<<15)
#define CCTRL_DFP (1<<14)

#define DDIAGMSK ((1<<DTAGLOW)-1)
#define IDIAGMSK ((1<<ITAGLOW)-1)

#define ICLOCK_BIT 6
#define DCLOCK_BIT 7

extern int asmgetdtag(int addr);
extern void asmsetdtag(int addr, int data);

extern int asmgetddata(int addr);
extern void asmsetddata(int addr, int data);

extern void setudata(int addr, int data);
extern int getudata(int addr);


extern int asmgetitag(int addr);
extern void asmsetitag(int addr, int data);

extern int asmgetidata(int addr);
extern void asmsetidata(int addr, int data);

extern void wsysreg(int addr, int data);
extern int rsysreg(int addr);

int icconf, dcconf, dsetsize, isetsize;
int dsetbits, isetbits;
int DSETS, DTAGLOW, DTAGAMSK, ITAGAMSK, ITAGLOW;

flush()
{
	asm(" flush");
}

getitag(addr, set)
int addr, set;
{
  int tag;

  tag = asmgetitag((addr & IDIAGMSK) + (set<<isetbits));
  return(tag);
}


setitag(addr, set, data)
int addr, set, data;
{
  asmsetitag((addr & IDIAGMSK) + (set<<isetbits), data);
}

setidata(addr, set, data)
int addr, set, data;
{
  asmsetidata((addr & IDIAGMSK) + (set<<isetbits), data);
}


getidata(addr, set)
int addr, set;
{
  int idata;

  idata = asmgetidata((addr & IDIAGMSK) + (set<<isetbits));
  return(idata);
}



setdtag(addr, set, data)
int addr, set, data;
{
  asmsetdtag((addr & DDIAGMSK) + (set<<dsetbits), data);
}

setddata(addr, set, data)
int addr, set, data;
{
  asmsetddata((addr & DDIAGMSK) + (set<<dsetbits), data);
}

chkdtag(addr)
int addr;
{
  int tm[16];
  int tmp, i;

  tmp = 0;
  for (i=0;i<DSETS;i++) {
    if (((asmgetdtag((addr & DDIAGMSK) + (i<<dsetbits))) & DTAGAMSK) == (addr & DTAGAMSK))
      tmp++;
  }
  if (tmp != 0)
    return 0;
  else
    return 1;
}

getdtag(addr, set)
int addr;
{
  int tag;

  tag = asmgetdtag((addr & DDIAGMSK) + (set<<dsetbits));
  return(tag);
}


getddata(addr, set)
int addr, set;
{
  int ddata;

  ddata = asmgetddata((addr & DDIAGMSK) + (set<<dsetbits));
  return(ddata);
}



dma(int addr, int len,  int write)
{
	volatile unsigned int *dm = (unsigned int *) 0xa0000000;

	dm[0] = addr;
	dm[1] = (write <<13) + 0x1000 + len;

}

extern int xgetpsr();
extern void setpsr(int psr);

extern void flushi(int addr, int data);
extern void flushd(int addr, int data);

extern line0();
extern line1();
extern line2();
extern line3();


#define ITAGMASK ((1<<ILINESZ)-1)
#define DTAGMASK (~((1<<DLINESZ)-1))
#define DIAGADDRMASK ((1<<DTAGLOW)-1)

void cachetest(void)
{
    report_subtest(CACHE_TEST+(get_pid()<<4));

    maintest();
    wsysreg(0, 0x0081000f);
}

void cachetest4(void)
{
    int i = 0;

    report_subtest(CACHE_TEST);

    if (((rsysreg(8) >> 28) & 3) != 3) { /* ic dynamic replacement */
       i = 3;
    }

    if (((rsysreg(12) >> 28) & 3) != 3) { /* dc dynamic replacement */
       i = 3;
    }

    /* if dynamic replacement then test repl = 3, 2, 1, 0 */
    while (i >= 0) {
       wsysreg(8, (rsysreg(8) & ~(3 << 28)) | (i << 28));
       wsysreg(12, (rsysreg(12) & ~(3 << 28)) | (i << 28));
       maintest();
       i--;
    }

    wsysreg(8, (rsysreg(8) & ~(3 << 28)) | (1 << 28));
    wsysreg(12, (rsysreg(12) & ~(3 << 28)) | (1 << 28));
    wsysreg(0, 0x0081000f);
}

static unsigned long lda0x0c(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x0c, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x0c(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x0c" : : "r"(data),"r"(addr));
}

static unsigned long lda0x0d(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x0d, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x0d(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x0d" : : "r"(data),"r"(addr));
}

static unsigned long lda0x0e(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x0e, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x0e(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x0e" : : "r"(data),"r"(addr));
}

static unsigned long lda0x0f(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x0f, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x0f(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x0f" : : "r"(data),"r"(addr));
}

static unsigned long lda0x1e(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x1e, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x1e(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x1e" : : "r"(data),"r"(addr));
}

static void sta0x1c(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x1c" : : "r"(data),"r"(addr));
}

static unsigned long lda0x26(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x26, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x26(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x26" : : "r"(data),"r"(addr));
}

static unsigned long lda0x27(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x27, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x27(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x27" : : "r"(data),"r"(addr));
}

void regfltest(unsigned long freeaddr)
{
        unsigned long iccfg, dccfg;
        unsigned long iways, isets, iwaysize, iclsizep, iclsize, itagmask;
        unsigned long dways, dsets, dwaysize, dclsizep, dclsize, dtagmask;
        int w,s,a,d,r,ra,rv,ev;
        int testcase;
        unsigned flmask, fladdr;
        int nrepli,nrepld,nrepliw,nrepldw;
        /* Get sizes */
        iccfg = rsysreg(8);
        iways = ((iccfg >> 24) & 7) + 1;
        iclsizep = ((iccfg >> 16) & 7) + 2;
        iclsize = 1 << iclsizep;
        iwaysize = 1024 << ((iccfg >> 20) & 15);
        isets = iwaysize >> iclsizep;
        itagmask = ~(iwaysize-1);
        dccfg = rsysreg(12);
        dways = ((dccfg >> 24) & 7) + 1;
        dclsizep = ((dccfg >> 16) & 7) + 2;
        dclsize = 1 << dclsizep;
        dwaysize = 1024 << ((dccfg >> 20) & 15);
        dsets = dwaysize >> dclsizep;
        dtagmask = ~(dwaysize-1);
        for (testcase=0; testcase<5; testcase++) {
                /* Populate IC and DC tags to addresses we know we don't use in the
                 * test SW Note some will be replaced due to the test SW itself
                 * running */
                for (w=0,a=0,d=freeaddr; w<iways; w++) {
                        for (s=0; s<isets; s++, a+=iclsize, d+=(iclsize+(3<<12))) {
                                sta0x0c(a,d|1);
                        }
                }
                for (w=0,a=0,d=freeaddr; w<dways; w++) {
                        for (s=0; s<dsets; s++, a+=dclsize, d+=(iclsize+(7<<12))) {
                                /* also write the snoop tag in order to avoid accidental snoops
                                 * against the current tag and also to silence the simualtion monitor  */
                                sta0x1e(a,d|1);
                                sta0x0e(a,d|1);
                        }
                }
                /* Decide settings for partial flush */
                switch (testcase) {
                case 0:
                default:/* Case 0: Match none */
                        fladdr = 0;
                        flmask = ~0;
                        break;
                case 1: /* Case 1: Match all */
                        fladdr = 0;
                        flmask = 0;
                        break;
                case 2: /* Case 2: Match some based on tag bits */
                        fladdr = (3 << 20);
                        flmask = (15 << 20);
                        break;
                case 3: /* Case 3: Match some based on index bits (limit indexes searched) */
                        fladdr = 0x80;
                        flmask = 0xf0;
                        break;
                case 4: /* Case 4: Match some based on index and tag bits */
                        fladdr = 0x80 | (1 << 20);
                        flmask = 0xf0 | (15 << 20);
                        break;
                }
                /* Perform partial flush */
                wsysreg(0x18, flmask);
                wsysreg(0x1C, fladdr | 3);
                /* Check tags */
                nrepli = nrepld = nrepliw = nrepldw = 0;
                for (w=0,a=0,d=freeaddr; w<iways; w++) {
                        for (s=0; s<isets; s++, a+=iclsize, d+=(iclsize+(3<<12))) {
                                r = lda0x0c(a);
                                if ( ((r & 0xff000000) != freeaddr) && ((r & 1) == 1)) {
                                        nrepli++; /* cache line was replaced by (this) test code */
                                } else if (((r & itagmask) != (d & itagmask)) && ((r & 1)==1)) {
                                        fail(60+(testcase<<3)); /* tag address changed unexpectedly */
                                } else {
                                        ra = (d & itagmask) | (a & (~itagmask));
                                        ev = ((ra & flmask) == fladdr)?0:1;
                                        rv = r & 1;
                                        if (ev==1 && rv==0 &&
                                            ((a & (~itagmask) & flmask) == (fladdr & (~itagmask) & flmask))) {
                                                /* cache line was replaced between population and flush
                                                 * and then got flushed out */
                                                nrepliw++;
                                        } else if (ev != rv)
                                                fail(61+(testcase<<3));
                                }
                        }
                }
                if (nrepli > 24 || nrepliw > 1) fail(62+(testcase<<3));
                for (w=0,a=0,d=freeaddr; w<dways; w++) {
                        for (s=0; s<dsets; s++, a+=dclsize, d+=(dclsize+(7<<12))) {
                                r = lda0x0e(a);
                                if ( ((r & 0xff000000) != freeaddr) && ((r & 1) == 1)) {
                                        nrepld++; /* cache line was replaced by (this) test data */
                                } else if (((r & dtagmask) != (d & dtagmask)) && ((r & 1)==1)) {
                                        fail(63+(testcase<<3)); /* tag address changed unexpectedly */
                                } else {
                                        ra = (d & dtagmask) | (a & (~dtagmask));
                                        ev = ((ra & flmask) == fladdr)?0:1;
                                        rv = r & 1;
                                        if (ev==1 && rv==0 &&
                                            ((a & (~dtagmask) & flmask) == (fladdr & (~dtagmask) & flmask))) {
                                                /* cache line was replaced between population and flush
                                                 * and then got flushed out */
                                                nrepldw++;
                                        } else if (ev != rv)
                                                fail(64+(testcase<<3));
                                }
                        }
                }
                if (nrepld > 8 || nrepldw > 1) { fail(65+(testcase<<3)); }
        }
}

void cachetest5(void)
{
  unsigned long leon5cfg,ftcfg,cft;
  report_subtest(CACHE_TEST+(get_pid()<<4));
  /* check if we have FT */
  leon5cfg = rsysreg(0x10);
  if (((leon5cfg >> 29) & 1) != 0) ftcfg=rsysreg(0x14); else ftcfg=0;
  cft = ftcfg >> 30;
  if (cft != 0) {
          /* clear error counters  */
          wsysreg(0x38,0xffffffff);
  }
  maintest5();
  wsysreg(0, 0x0081000f);
  regfltest(0x50000000);
  if (cft != 0) cfttest5(cft);
}

long long int getdw();

void cache_test_init_state()
{
	int ITAGS, DTAGS;
	int ILINESZ, DLINESZ;
	int ITAG_BITS, ILINEBITS, DTAG_BITS, DLINEBITS;

	ILINEBITS = (icconf >> 16) & 7;
	DLINEBITS = ((dcconf >> 16) & 7);
	ITAG_BITS = ((icconf >> 20) & 15) + 8 - ILINEBITS;
	DTAG_BITS = ((dcconf >> 20) & 15) + 8 - DLINEBITS;
	isetsize = (1<<((icconf >> 20) & 15)) * 1024;
	dsetsize = (1<<((dcconf >> 20) & 15)) * 1024;
	isetbits = ((icconf >> 20) & 15) + 10;
	dsetbits = ((dcconf >> 20) & 15) + 10;
	ITAGS = (1 << ITAG_BITS);
	ILINESZ = (1 << ILINEBITS);
	DTAGS = (1 << DTAG_BITS);
 	DLINESZ = (1 << DLINEBITS);
	ITAGAMSK = 0x7fffffff - (1 << (ITAG_BITS + ILINEBITS +2)) + 1;
	DTAGAMSK = 0x7fffffff - (1 << (DTAG_BITS + DLINEBITS +2)) + 1;
	DSETS = ((dcconf >> 24) & 3) + 1;

	ITAGLOW = 10 + ((icconf >> 20) & 15);
	DTAGLOW = 10 + ((dcconf >> 20) & 15);
}


maintest()
{

	volatile double mrl[8192 + 8]; /* enough for 64 K caches */
	volatile int mrx[16];
	volatile double *ll = (double *) mrx;
	volatile int *mr = (int *) mrl;
	volatile unsigned char *mrc = (char *) mrl;
	volatile unsigned short *mrh = (short *) mrl;
	volatile long long int dw;
	int vbits, vpos, addrmsk;
	int i, j, tmp, cachectrl;
	int ITAGS, DTAGS;
	int ILINESZ, DLINESZ;
	int ITAG_BITS, ILINEBITS, DTAG_BITS, DLINEBITS;
	int IVALMSK, tag, data;
	int ISETS;
	int (*line[4])() = {line0, line1, line2, line3};

	cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x0f);
	do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
	flush();
	do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
	cachectrl = rsysreg(0); wsysreg(0, cachectrl | 0x0081000f);

	icconf = rsysreg(8);
	dcconf = rsysreg(12);

	ILINEBITS = (icconf >> 16) & 7;
	DLINEBITS = ((dcconf >> 16) & 7);
	ITAG_BITS = ((icconf >> 20) & 15) + 8 - ILINEBITS;
	DTAG_BITS = ((dcconf >> 20) & 15) + 8 - DLINEBITS;
	isetsize = (1<<((icconf >> 20) & 15)) * 1024;
	dsetsize = (1<<((dcconf >> 20) & 15)) * 1024;
	isetbits = ((icconf >> 20) & 15) + 10;
	dsetbits = ((dcconf >> 20) & 15) + 10;
	ITAGS = (1 << ITAG_BITS);
	ILINESZ = (1 << ILINEBITS);
	DTAGS = (1 << DTAG_BITS);
 	DLINESZ = (1 << DLINEBITS);
	IVALMSK = (1 << ILINESZ)-1;
	ITAGAMSK = 0x7fffffff - (1 << (ITAG_BITS + ILINEBITS +2)) + 1;
	DTAGAMSK = 0x7fffffff - (1 << (DTAG_BITS + DLINEBITS +2)) + 1;
	ISETS = ((icconf >> 24) & 3) + 1;
	DSETS = ((dcconf >> 24) & 3) + 1;

	ITAGLOW = 10 + ((icconf >> 20) & 15);
	DTAGLOW = 10 + ((dcconf >> 20) & 15);

	/**** INSTRUCTION CACHE TESTS ****/

	/* Skip test if ISETS=1 as the location of the test function and of the test code
	 * may end up on the same sets in the cache causing the test function to be evicted.
	 */
	if (((cachectrl >> ITE_BIT) & 3) == 0 && ISETS>1) { // skip test during err. injection
	  for (i=0;i<ISETS;i++) {
	    line[i]();
	  }

	  cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x03); /* disable icache */
	/* check tags */
	  tmp = 0;
	  for (i=0;i<ISETS;i++) {
 	    for (j=0;j<ISETS;j++) {
	      tag = getitag((int) line[i], j);
	      if ( ((tag & IVALMSK) == IVALMSK) && ((tag & ITAGAMSK) == (((int) line[i]) & ITAGAMSK)) )
	        tmp++;
	    }
	  }
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl | 3); /* enable icache */
	  if (tmp == 0) fail(1);

	/* iparity checks */
        if (((cachectrl >> CPP_CONF_BIT) & CPP_CONF_MASK) == CPP_CONF_PARITY) {
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x3fc0);
	  line2();
	  wsysreg(0, (cachectrl | CPTB_MASK) & ~3);
	  for (i=0;i<ISETS;i++) {
	    setidata((int) line2, i, 0);
	  }
	  wsysreg(0, (cachectrl | CPTB_MASK));
	  /* Add nop to ensure time between enabling icache and calling line2
	     to get the parity error. The short time made some template designs
	     fail. */
	  asm("nop;");
	  line2();
	  cachectrl = rsysreg(0);
	  if (((cachectrl >> IDE_BIT) & 3) != 1) fail(2);
	  do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));

	  asm("nop;");
	  wsysreg(0, cachectrl & ~3);
	  setitag((int) line2, 0, 0);
	  asm("nop;");
	  cachectrl = rsysreg(0); wsysreg(0, (cachectrl & ~CPTB_MASK) | 3);
	  asm("nop;");
	  line2();
	  cachectrl = rsysreg(0);
	  if (((cachectrl >> ITE_BIT) & 3) != 1) fail(3);
	}


	/**** DATA CACHE TESTS ****/

	flush();
	do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));

	for (i=0;i<DSETS;i++) {
	  setdtag((int) mr, i, 0); 	/* clear tags */
	}
	for (i=0;i<31;i++) mr[i] = 0;
	mr[0] = 5; mr[1] = 1; mr[2] = 2; mr[3] = 3;

	/* check that write does not allocate line */
	if (chkdtag((int) mr) == 0) fail(5);

	if (mr[0] != 5) fail(6);

	/* check that line was allocated */
   	if (chkdtag((int) mr) != 0) fail(7);

	/* check that data is in cache */
	for (i=0;i<DSETS;i++) {
		setddata((int)mr,i,0); setddata((int) &mr[1], i, 0);
	}
	getudata((int) &mr[0]); getudata((int) &mr[8]);
	getudata((int) &mr[16]); getudata((int) &mr[24]);
	tmp = 0;
	for (i=0;i<DSETS;i++) { if (getddata((int) mr, i) == 5) tmp++; }
	if (tmp == 0) fail(8);

	*ll = mrl[0];
	if ((mrx[0] != 5) || (mrx[1] != 1)) fail(9);
	tmp = 0;
	for (i=0;i<DSETS;i++) {
	  if (getddata((int) &mr[1], i) == 1) tmp++;
	}
	if (tmp != 1) fail(10);

	/* dcache parity */
	if (((cachectrl >> CPP_CONF_BIT) & CPP_CONF_MASK) == CPP_CONF_PARITY) {
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~CE_CLEAR);
	  setddata(&mrx[0],0,0);
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl | CPTB_MASK);
	  for (i=0;i<DSETS;i++) setddata((int *)mrx,i,5);
	  *((char *) mrx) = 1;
	  if (mrx[0] != 0x01000005) fail(11);
	  cachectrl = rsysreg(0);
	  if (((cachectrl >> DDE_BIT) & 3) != 1) fail(12);
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~CPTB_MASK);
	  do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
	  setddata(&mrx[0],0,0);
	  cachectrl = rsysreg(0); wsysreg(0, cachectrl | CPTB_MASK);
	  do cachectrl = rsysreg(0); while (!(cachectrl & CPTB_MASK));
	  for (i=0;i<DSETS;i++) {
	    setdtag((int *)mrx,i,(1 << DLINESZ)-1);
	  }
	  wsysreg(0, cachectrl & ~CPTB_MASK);
	  do cachectrl = rsysreg(0); while (cachectrl & CPTB_MASK);
	  if (mrx[0] != 0x01000005) fail(13);
//	  if (getddata(&mr[0],0) != 5) fail(14);
	  cachectrl = rsysreg(0); if (((cachectrl >> DTE_BIT) & 3) != 1) fail(15);
//	  if ((getdtag(mrx,1) & DTAGMASK) != (1 <<((((int) mrx)>>2)&(DLINESZ-1)))) fail(16);
	  *((volatile long long int *) &dw) = 0x0000001100000055LL;
	  cachectrl = rsysreg(0); wsysreg(0, (cachectrl | CPTB_MASK) & ~DDE_MASK);
	  do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
	  getdw(&dw);
	  for (i=0;i<DSETS;i++) {
	    setddata(((int)&dw)+4,i,0x00000055);
	  }
	  if (getdw(&dw) != 0x0000001100000055LL) fail(16);
	  cachectrl = rsysreg(0); if (((cachectrl >> DDE_BIT) & 3) != 1) fail(16);
	  wsysreg(0, cachectrl & (~CE_CLEAR & ~CPTB_MASK));
	  do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
	}

	/* check that tag is properly replaced */
	mr[0] = mr[1];
	mr[0] = 5; mr[1] = 1; mr[2] = 2; mr[3] = 3;
	mr[DTAGS*DLINESZ] = 0xbbbbbbbb;

	/* check that tag is not evicted on write miss */
	if (chkdtag((int) mr) != 0) fail(17);

	/* check that write update memory ok */
	if (mr[DTAGS*DLINESZ] != 0xbbbbbbbb) fail(18);


	/* check that valid bits have been reset */
/* 	if ((getdtag(mr) & DTAGMASK) != (1 <<((((int) mr)>>2)&(DLINESZ-1))))  */
/* 		fail(19); */
/* 	tmp = 0; */
/* 	if ((getdtag((int) mr & DIAGADDRMASK + i*dsetsize) & DTAGMASK) != (1 <<((((int) mr)>>2)&(DLINESZ-1)))) */
/* 	  tmp = 1; */
/* 	if (tmp == 1)  fail(19); */


      }
	/* check partial word access */

      mr[8] = 0x01234567;
      mr[9] = 0x89abcdef;
      if (mrc[32] != 0x01) fail(26);
      if (mrc[33] != 0x23) fail(27);
      if (mrc[34] != 0x45) fail(28);
      if (mrc[35] != 0x67) fail(29);
      if (mrc[36] != 0x89) fail(30);
      if (mrc[37] != 0xab) fail(31);
      if (mrc[38] != 0xcd) fail(32);
      if (mrc[39] != 0xef) fail(33);
      if (mrh[16] != 0x0123) fail(34);
      if (mrh[17] != 0x4567) fail(35);
      if (mrh[18] != 0x89ab) fail(36);
      if (mrh[19] != 0xcdef) fail(37);
      mrc[32] = 0x30; if (mr[8] != 0x30234567) fail(39);
      mrc[33] = 0x31; if (mr[8] != 0x30314567) fail(40);
      mrc[34] = 0x32; if (mr[8] != 0x30313267) fail(41);
      mrc[35] = 0x33; if (mr[8] != 0x30313233) fail(42);
      mrc[36] = 0x34; if (mr[9] != 0x34abcdef) fail(43);
      mrc[37] = 0x35; if (mr[9] != 0x3435cdef) fail(44);
      mrc[38] = 0x36; if (mr[9] != 0x343536ef) fail(45);
      mrc[39] = 0x37; if (mr[9] != 0x34353637) fail(46);
      mrh[16] = 0x4041; if (mr[8] != 0x40413233) fail(47);
      mrh[17] = 0x4243; if (mr[8] != 0x40414243) fail(48);
      mrh[18] = 0x4445; if (mr[9] != 0x44453637) fail(49);
      mrh[19] = 0x4647; if (mr[9] != 0x44454647) fail(50);

	/*
	if (((lr->leonconf >> 2) & 3) == 3) { dma((int)&mr[0], 9, 1); }
	if (((lr->leonconf >> 2) & 3) == 3) { dma((int)&mr[0], 9, 1); }
	*/

	/* write data to the memory */
      flush();
      for (i=0;i<DSETS;i++) {
	for (j=0;j<DLINESZ;j++) {
	  mr[j+(i<<dsetbits)] = ((i<<16) | j);
	}
      }

      if (((cachectrl >> ITE_BIT) & 3) == 0) { // skip test during err. injection
	/* check that write miss does not allocate line */
	do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_DFP));
	for (i=0;i<DSETS;i++) {
	  if ((getdtag((int) mr, i) & DTAGAMSK) == ((int) mr & DTAGAMSK))
	    fail(51);
	}

	/* check flush operation */
	/* check that flush clears valid bits */
	/*
	cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x0f);
	flushi();
	do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP));

	if (chkitags(ITAG_MAX_ADDRESS,(1<<(ILINEBITS + 2)),0,0) & ((1<<ILINESZ)-1))
		fail(51);

	for (i

	lr->cachectrl |= 0x03;
	flushd();
	while(lr->cachectrl & CCTRL_DFP) {}

	if (chkdtags(DTAG_MAX_ADDRESS,(1<<(DLINEBITS + 2)),0,0) & ((1<<DLINESZ)-1))
		fail(52);
	*/

	/* flush();
	setdtag(0,0,0x11111111);
	setdtag(0,1,0x22222222);
	setdtag(0,2,0x33333333);
	setdtag(0,3,0x44444444);*/

	cachectrl = rsysreg(0); wsysreg(0, cachectrl | 0xf);
      }

      return(0);

/* to be tested: diag access during flush, diag byte/halfword access,
   write error, cache freeze operation */

}

void maintest5(void)
{

        volatile double mrl[8192 + 8]; /* enough for 64 K caches */
        volatile int mrx[16];
        volatile double *ll = (double *) mrx;
        volatile int *mr = (int *) mrl;
        volatile unsigned char *mrc = (char *) mrl;
        volatile unsigned short *mrh = (short *) mrl;
        volatile long long int dw;
        int vbits, vpos, addrmsk;
        int i, j, tmp, cachectrl;
        int ITAGS, DTAGS;
        int ILINESZ, DLINESZ;
        int ITAG_BITS, ILINEBITS, DTAG_BITS, DLINEBITS;
        int IVALMSK, tag, data;
        int ISETS;
        int (*line[4])() = {line0, line1, line2, line3};

        cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x0f);
        do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
        flush();
        do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));
        cachectrl = rsysreg(0); wsysreg(0, cachectrl | 0x0081000f);

        icconf = rsysreg(8);
        dcconf = rsysreg(12);

        ILINEBITS = (icconf >> 16) & 7;
        DLINEBITS = ((dcconf >> 16) & 7);
        ITAG_BITS = ((icconf >> 20) & 15) + 8 - ILINEBITS;
        DTAG_BITS = ((dcconf >> 20) & 15) + 8 - DLINEBITS;
        isetsize = (1<<((icconf >> 20) & 15)) * 1024;
        dsetsize = (1<<((dcconf >> 20) & 15)) * 1024;
        isetbits = ((icconf >> 20) & 15) + 10;
        dsetbits = ((dcconf >> 20) & 15) + 10;
        ITAGS = (1 << ITAG_BITS);
        ILINESZ = (1 << ILINEBITS);
        DTAGS = (1 << DTAG_BITS);
        DLINESZ = (1 << DLINEBITS);
        IVALMSK = (1 << ILINESZ)-1;
        ITAGAMSK = 0x7fffffff - (1 << (ITAG_BITS + ILINEBITS +2)) + 1;
        DTAGAMSK = 0x7fffffff - (1 << (DTAG_BITS + DLINEBITS +2)) + 1;
        ISETS = ((icconf >> 24) & 3) + 1;
        DSETS = ((dcconf >> 24) & 3) + 1;

        ITAGLOW = 10 + ((icconf >> 20) & 15);
        DTAGLOW = 10 + ((dcconf >> 20) & 15);

        /**** INSTRUCTION CACHE TESTS ****/

        for (i=0;i<ISETS;i++) {
                line[i]();
        }

        cachectrl = rsysreg(0); wsysreg(0, cachectrl & ~0x03); /* disable icache */
        /* check tags */
        tmp = 0;
        for (i=0;i<ISETS;i++) {
                for (j=0;j<ISETS;j++) {
                        tag = getitag((int) line[i], j);
                        if ( ((tag & IVALMSK) == IVALMSK) && ((tag & ITAGAMSK) == (((int) line[i]) & ITAGAMSK)) )
                                tmp++;
                }
        }
        cachectrl = rsysreg(0); wsysreg(0, cachectrl | 3); /* enable icache */
        if (tmp == 0) fail(1);

        /**** DATA CACHE TESTS ****/

        flush();
        do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_IFP | CCTRL_DFP));

        for (i=0;i<DSETS;i++) {
                setdtag((int) mr, i, ((i+1)<<16) | 0);          /* clear tags */
        }
        for (i=0;i<31;i++) mr[i] = 0;
        mr[0] = 5; mr[1] = 1; mr[2] = 2; mr[3] = 3;

        /* check that write does not allocate line */
        if (chkdtag((int) mr) == 0) fail(5);

        if (mr[0] != 5) fail(6);

        /* check that line was allocated */
        if (chkdtag((int) mr) != 0) fail(7);

        /* check that data is in cache */
        for (i=0;i<DSETS;i++) {
                setddata((int)mr,i,0); setddata((int) &mr[1], i, 0);
        }
        getudata((int) &mr[0]); getudata((int) &mr[8]);
        getudata((int) &mr[16]); getudata((int) &mr[24]);
        tmp = 0;
        for (i=0;i<DSETS;i++) { if (getddata((int) mr, i) == 5) tmp++; }
        if (tmp == 0) fail(8);

        *ll = mrl[0];
        if ((mrx[0] != 5) || (mrx[1] != 1)) fail(9);
        tmp = 0;
        for (i=0;i<DSETS;i++) {
                if (getddata((int) &mr[1], i) == 1) tmp++;
        }
        if (tmp != 1) fail(10);

        /* check that tag is properly replaced */
        mr[0] = mr[1];
        mr[0] = 5; mr[1] = 1; mr[2] = 2; mr[3] = 3;
        mr[DTAGS*DLINESZ] = 0xbbbbbbbb;

        /* check that tag is not evicted on write miss */
        if (chkdtag((int) mr) != 0) fail(17);

        /* check that write update memory ok */
        if (mr[DTAGS*DLINESZ] != 0xbbbbbbbb) fail(18);


        /* check partial word access */

        mr[8] = 0x01234567;
        mr[9] = 0x89abcdef;
        if (mrc[32] != 0x01) fail(26);
        if (mrc[33] != 0x23) fail(27);
        if (mrc[34] != 0x45) fail(28);
        if (mrc[35] != 0x67) fail(29);
        if (mrc[36] != 0x89) fail(30);
        if (mrc[37] != 0xab) fail(31);
        if (mrc[38] != 0xcd) fail(32);
        if (mrc[39] != 0xef) fail(33);
        if (mrh[16] != 0x0123) fail(34);
        if (mrh[17] != 0x4567) fail(35);
        if (mrh[18] != 0x89ab) fail(36);
        if (mrh[19] != 0xcdef) fail(37);
        mrc[32] = 0x30; if (mr[8] != 0x30234567) fail(39);
        mrc[33] = 0x31; if (mr[8] != 0x30314567) fail(40);
        mrc[34] = 0x32; if (mr[8] != 0x30313267) fail(41);
        mrc[35] = 0x33; if (mr[8] != 0x30313233) fail(42);
        mrc[36] = 0x34; if (mr[9] != 0x34abcdef) fail(43);
        mrc[37] = 0x35; if (mr[9] != 0x3435cdef) fail(44);
        mrc[38] = 0x36; if (mr[9] != 0x343536ef) fail(45);
        mrc[39] = 0x37; if (mr[9] != 0x34353637) fail(46);
        mrh[16] = 0x4041; if (mr[8] != 0x40413233) fail(47);
        mrh[17] = 0x4243; if (mr[8] != 0x40414243) fail(48);
        mrh[18] = 0x4445; if (mr[9] != 0x44453637) fail(49);
        mrh[19] = 0x4647; if (mr[9] != 0x44454647) fail(50);

        /*
          if (((lr->leonconf >> 2) & 3) == 3) { dma((int)&mr[0], 9, 1); }
          if (((lr->leonconf >> 2) & 3) == 3) { dma((int)&mr[0], 9, 1); }
        */

        /* write data to the memory */
        flush();
        for (i=0;i<DSETS;i++) {
                for (j=0;j<DLINESZ;j++) {
                        mr[j+(i<<dsetbits)] = ((i<<16) | j);
                }
        }

        /* check that write miss does not allocate line */
        do cachectrl = rsysreg(0); while(cachectrl & (CCTRL_DFP));
        for (i=0;i<DSETS;i++) {
                if ((getdtag((int) mr, i) & DTAGAMSK) == ((int) mr & DTAGAMSK))
                        fail(51);
        }

        cachectrl = rsysreg(0); wsysreg(0, cachectrl | 0xf);

        return(0);

        /* to be tested: diag access during flush, diag byte/halfword access,
           write error, cache freeze operation */
}

static void itag_inject(void *addr, int errtype, int iwaysize, int itagmask)
{
        unsigned long a = (unsigned long)addr, ta, td;
        ta = a & (~itagmask);
        while (1) {
                td = lda0x0c(ta);
                if ((td & itagmask) == (a & itagmask)) break;
                ta += iwaysize;
        }
        wsysreg(0x30, errtype);
        lda0x0c(ta);
        /* Some NOP:s to ensure the injection has effect before the next
         * function call */
        asm volatile ("nop; nop; nop; nop; nop");
}

static void idata_inject(void *addr, int errtype, int iwaysize, int itagmask)
{
        unsigned long a = (unsigned long)addr, ta, td;
        ta = a & (~itagmask);
        while (1) {
                td = lda0x0c(ta);
                if ((td & itagmask) == (a & itagmask)) break;
                ta += iwaysize;
        }
        wsysreg(0x30, errtype);
        lda0x0d(ta);
        /* Some NOP:s to ensure the injection has effect before the next
         * function call */
        asm volatile ("nop; nop; nop; nop; nop");
}

static void dtag_inject(void *addr, int errtype, int dwaysize, int dtagmask)
{
        unsigned long a = (unsigned long)addr, ta, td;
        ta = a & (~dtagmask);
        while (1) {
                td = lda0x0e(ta);
                if ((td & dtagmask) == (a & dtagmask)) break;
                ta += dwaysize;
        }
        wsysreg(0x30, errtype);
        lda0x0e(ta);
}

static void ddata_inject(void *addr, int errtype, int dwaysize, int dtagmask)
{
        unsigned long a = (unsigned long)addr, ta, td;
        ta = a & (~dtagmask);
        while (1) {
                td = lda0x0e(ta);
                if ((td & dtagmask) == (a & dtagmask)) break;
                ta += dwaysize;
        }
        wsysreg(0x30, errtype);
        lda0x0f(ta);
}

static void dstag_inject(void *addr, int errtype, int dwaysize, int dtagmask)
{
        unsigned long a = (unsigned long)addr, ta, td;
        ta = a & (~dtagmask);
        while (1) {
                td = lda0x1e(ta);
                if ((td & dtagmask) == (a & dtagmask)) break;
                ta += dwaysize;
        }
        wsysreg(0x30, errtype);
        lda0x1e(ta);
}

static unsigned long regld(void *addr)
{
        unsigned long r;
        asm volatile ("ld [%1], %0" : "=r"(r) : "r"((unsigned long)addr));
        return r;
}

void cfttest5(int cft)
{
        unsigned long iccfg, dccfg;
        unsigned long iways, iwaysize, itagmask;
        unsigned long dways, dwaysize, dtagmask;
        unsigned long errctr;
        unsigned long l=0,v;
        int cemode, correxp, cntexp;
        /* Skip test if error injection is not supported by technology */
        if ((rsysreg(0x30) >> 30) == 0) return;
        /* Get sizes */
        iccfg = rsysreg(8);
        iways = ((iccfg >> 24) & 7) + 1;
        iwaysize = 1024 << ((iccfg >> 20) & 15);
        itagmask = ~(iwaysize-1);
        dccfg = rsysreg(12);
        dways = ((dccfg >> 24) & 7) + 1;
        dwaysize = 1024 << ((dccfg >> 20) & 15);
        dtagmask = ~(dwaysize-1);
        for (cemode=0; cemode<4; cemode++) {
                if (cemode == 2) continue;
                if (cemode == 1 && cft != 1) continue;
                if (cemode==0) correxp=1; else correxp=0;
                wsysreg(0x14, cemode<<17);
                /* Icache EI corr error */
                line0();
                itag_inject(&line0,1,iwaysize,itagmask);
                line0();
                errctr = rsysreg(0x38);
                cntexp = 1;
                if (cemode == 1) {
                        /* May get multiple errors since tag read once per
                         * instruction pair */
                        cntexp = (errctr >> 8) & 3;
                        if (cntexp == 0) cntexp++;
                }
                if (errctr != ((correxp<<15)|(cntexp<<8))) fail(128);
                if (cemode == 1) itag_inject(&line0,0,iwaysize,itagmask);
                wsysreg(0x38,~0);
                line0();
                errctr = rsysreg(0x38);
                if (errctr != 0) fail(129);
                idata_inject(&line0,1,iwaysize,itagmask);
                line0();
                errctr = rsysreg(0x38);
                if (errctr != ((correxp<<15)|(1<<6))) fail(130);
                if (cemode == 1) idata_inject(&line0,0,iwaysize,itagmask);
                wsysreg(0x38,~0);
                line0();
                errctr = rsysreg(0x38);
                if (errctr != 0) fail(131);
                /* Dcache EI corr error */
                regld(&l);
                dtag_inject(&l,1|(1<<2)|(1<<8),dwaysize,dtagmask);
                v = regld(&l);
                errctr = rsysreg(0x38);
                if (errctr != ((correxp<<15)|(1<<4)) || v != 0) fail(132);
                if (cemode == 1) dtag_inject(&l,0,dwaysize,dtagmask);
                wsysreg(0x38,~0);
                regld(&l);
                ddata_inject(&l,1,dwaysize,dtagmask);
                v = regld(&l);
                errctr = rsysreg(0x38);
                if (errctr != ((correxp<<15)|(1<<0)) || v != 0) fail(133);
                if (cemode == 1) ddata_inject(&l,0,dwaysize,dtagmask);
                wsysreg(0x38,~0);
                v = regld(&l);
                errctr = rsysreg(0x38);
                if (errctr != 0 || v != 0) fail(134);
                /* snoop tag EI */
                regld(&l);
                dstag_inject(&l,1|(1<<2),dwaysize,dtagmask);
                v = regld(&l);
                errctr = rsysreg(0x38);
                if (errctr != 0 || v != 0) fail(135);
                /*   perform write with MMU bypass to trigger snoop logic
                 *     that will lead to a correction after some delay */
                sta0x1c(&l,43);
                do { v = regld(&l); } while (v==0);
                errctr = rsysreg(0x38);
                /* Note error counter may step up more than one if there are other writes
                 * to the same set seen on the AHB bus */
                if ((errctr & (3<<2)) == 0 || v != 43) fail(136);
                wsysreg(0x38,~0);
                sta0x1c(&l,0);
                do { v = regld(&l); } while (v==43);
                errctr = rsysreg(0x38);
                if (errctr != 0 || v != 0) fail(137);
        }
        wsysreg(0x14, 0);
}

/* SPARC V8 TT values */
#define MYTT_INSTRUCTION_ACCESS_EXCEPTION 1
#define MYTT_DATA_ACCESS_EXCEPTION 9
/* 0x8F is the software trap number for "set_supervisor" */
#define MYTT_SET_SUPERVISOR 0x8F

/*
 * User functions for enter supervisor/user mode. ABI compatible and requires
 * the SET_SUPERVISOR software trap to be installed before use.
 */
void systest_enter_supervisor(void);
void systest_enter_user(void);

/* defined in mmu_asm.S */
extern void systest_trap_set_supervisor(void);
/* defined in cacheasm.S */
extern void tcmtest_dexc_handler(void);
extern void tcmtest_iexc_handler(void);
extern int tcmtest_dummy_func(int);

extern volatile int tcmtest_dexc_ctr, tcmtest_dexc_addr;
extern volatile int tcmtest_iexc_ctr, tcmtest_iexc_addr;

static unsigned long get_tbr(void)
{
        unsigned long r;
        asm volatile (" mov %%tbr, %0" : "=r"(r) );
        return r;
}

volatile static int testvar=35;

void tcmtest5_prepare(void)
{
        unsigned long leon5cfg;
        leon5cfg = rsysreg(0x10);
        if ( ((leon5cfg >> 27) & 3) == 0 ) return; /* TCM not implemented */
        wsysreg(0x40,(1<<31)|(1<<15)); /* Wipe ITCM and DTCM */
}

/* Function to be executed out of ITCM. Computes the number of primes
 * smaller than the argument using a sieve. To prevent possible future
 * compiler optimizations from breaking it, the assembler code generated
 * by BCC2.2.1 with flags -S, -O2 and -mcpu=leon5 has been copied to
 * cacheasm.S.
 * tcmtest_itcmfunc_end is a pointer to the first instruction after the
 * tcmtest_itcmfunc function.
 */
extern int tcmtest_itcmfunc(int b);
extern int tcmtest_itcmfunc_size;
int tmctest_itcmtfunc_c(int b) {
      uint8_t p[b];
      for(int i=0; i<b; i++) {
            asm volatile ("nop"); /* prevent call to memset */
            p[i] = 1;
      }
      p[0] = 0;
      p[1] = 0;
      int count = 0;
      for(int i=0; i<b; i++) {
            if(p[i] == 1) {
                  count++;
                  for(int j=i*i; j<b; j+=i) {
                    p[j] = 0;
                  }
            }
      }
      return count;
}

static void tcmtest5_copy_itcmfunc(int itcmsz, unsigned long addr)
{
      int a;
      if ((1 << itcmsz) >= tcmtest_itcmfunc_size) {
            for(a=0; a<tcmtest_itcmfunc_size; a+=4) {
              sta0x26(addr + a, *(unsigned long*)(a + (unsigned long)tcmtest_itcmfunc));
            }
      } else if(itcmsz > 0) {
            /* fall back on simpler test if ITCM is very small
             * The result of the function in general does not agree
             * with the value from the larger function. But it does
             * agree for some arguments, such as 96, 100, and 120.
             * The minimum size is 16 bytes (1 address bit) */
            sta0x26(addr+0x0, 0x9de3bfa0); /* save  %sp, -96, %sp */
            sta0x26(addr+0x4, 0xb1362002); /* srl  %i0, 2, %i0 */
            sta0x26(addr+0x8, 0x81c7e008); /* ret */
            sta0x26(addr+0xc, 0x81e80000); /* restore */
      }
}

void tcmtest5(void)
{
        unsigned long leon5cfg, tcmcfg, ftcfg;
        int dtcmsz, itcmsz, i, j;
        int sumode;
        typedef int (*funcptr)(int);
        funcptr f = (funcptr)0x50000000;
        volatile unsigned long *lptr = (volatile unsigned long *)0x50000000;
        volatile unsigned long long *llptr = (volatile unsigned long long *)0x50000000;
        volatile unsigned short *sptr = (volatile unsigned short *)0x50000000;
        volatile unsigned char *cptr = (volatile unsigned char *)0x50000000;
        char pgtblbuf[4096];
        char *pgtblp;
        unsigned long test_func_addr, a, test_var_addr;
        funcptr test_func;
        volatile unsigned long *testvarp;
        int do_fttest, cft, eitype, cemode, correxp;
        unsigned long errctr;
        leon5cfg = rsysreg(0x10);
        if ( ((leon5cfg >> 27) & 3) == 0 ) return; /* TCM not implemented */
        report_subtest( (get_pid()<<4) | 2 );
        do {
                tcmcfg = rsysreg(0x40);
        } while ((tcmcfg & (1<<31))!=0 || (tcmcfg & (1<<15))!=0 );
        dtcmsz = tcmcfg & 31;
        itcmsz = (tcmcfg >> 16) & 31;
        /* Test ASI read and write to ITCM and DTCM memories */
        if (itcmsz > 0) {
                sta0x26(0,1);
                for (i=2; i<itcmsz; i++) {
                        sta0x26(1<<i, i);
                }
                if (lda0x26(0) != 1) fail(1);
                for (i=2; i<itcmsz; i++) {
                        if (lda0x26(1<<i) != i) fail(1);
                }
        }
        if (dtcmsz > 0) {
                sta0x27(0,1);
                for (i=2; i<dtcmsz; i++) {
                        sta0x27(1<<i, i);
                }
                if (lda0x27(0) != 1) fail(2);
                for (i=2; i<dtcmsz; i++) {
                        if (lda0x27(1<<i) != i) fail(2);
                }
        }
        /* Setup trap handler for supervisor-only check */
        bcc_set_trap(MYTT_INSTRUCTION_ACCESS_EXCEPTION, tcmtest_iexc_handler);
        bcc_set_trap(MYTT_DATA_ACCESS_EXCEPTION, tcmtest_dexc_handler);
        bcc_set_trap(MYTT_SET_SUPERVISOR, systest_trap_set_supervisor);
        /* region flush of trap table in Icache */
        wsysreg(0x18, ~0xfff);
        wsysreg(0x1c, (get_tbr() & (~0xfff)) | 2);
        /* Setup ITCM with simple function to call in test */
        tcmtest5_copy_itcmfunc(itcmsz, 0);
        /* Test ITCM in MMU-off configuration, all combinations of permissions */
        if (itcmsz > 0) {
                i = tcmtest_iexc_ctr;
                for (sumode=0; sumode<8; sumode++) {
                        /* sumode: 0:run as supervisor 1:run as user
                         *         0:clear itcmu bit, 2:set itcmu bit
                         *         0:clear itcmsu bit 4: set itcmsu bit*/
                        wsysreg(0x48, 0x50000000 | 1 | (((sumode >> 1)&3)<<3) );
                        if ((sumode & 1) != 0) systest_enter_user();
                        asm volatile ("nop; nop; nop; nop");
                        if (f(96) != 24) fail(3);
                        if (tcmtest_iexc_ctr != i) {
                                /* trap triggered */
                                i++;
                                if (tcmtest_iexc_addr != 0x50000000) fail(4);
                                if ((sumode & 1)==0 && (sumode & 4)!=0) fail(5);
                                if ((sumode & 1)!=0 && (sumode & 2)!=0) fail(6);
                        } else {
                                /* trap not triggered */
                                if ((sumode & 1)==0 && (sumode & 4)==0) fail(7);
                                if ((sumode & 1)!=0 && (sumode & 2)==0) fail(8);
                        }
                        if ( (sumode & 1) != 0) systest_enter_supervisor();
                }
        }
        /* Test DTCM in MMU-off configuration, all combinations of permissions */
        if (dtcmsz > 0) {
                i = tcmtest_dexc_ctr;
                for (sumode=0; sumode<32; sumode++) {
                        /* chkp(sumode); */
                        wsysreg(0x4C, 0x50000000 | 1 | (((sumode >> 1)&15)<<3) );
                        sta0x27(0, 0);
                        /* test write */
                        if ((sumode & 1) != 0) systest_enter_user();
                        *lptr = 0x11223344;
                        if ((sumode & 1) != 0) systest_enter_supervisor();
                        if (lda0x27(0) != 0x11223344) fail(9);
                        if (tcmtest_dexc_ctr != i) {
                                /* trap triggered */
                                i++;
                                if ((sumode & 1)==0 && (sumode & 16)!=0) fail(11);
                                if ((sumode & 1)!=0 && (sumode & 4)!=0) fail(12);
                                /* restore permissions setting for read test */
                                wsysreg(0x4C, 0x50000000 | 1 | (((sumode >> 1)&15)<<3) );
                        } else {
                                /* trap not triggered */
                                if ((sumode & 1)==0 && (sumode & 16)==0) fail(13);
                                if ((sumode & 1)!=0 && (sumode & 4)==0) fail(14);
                        }
                        /* test read */
                        if ((sumode & 1) != 0) systest_enter_user();
                        if (*lptr != 0x11223344) fail(15);
                        if ((sumode & 1) != 0) systest_enter_supervisor();
                        if (tcmtest_dexc_ctr != i) {
                                /* trap triggered */
                                i++;
                                if ((sumode & 1)==0 && (sumode & 8)!=0) fail(17);
                                if ((sumode & 1)!=0 && (sumode & 2)!=0) fail(18);
                        } else {
                                /* trap not triggered */
                                if ((sumode & 1)==0 && (sumode & 8)==0) fail(19);
                                if ((sumode & 1)!=0 && (sumode & 2)==0) fail(20);
                        }
                }
        }
        /* Setup MMU mapping for virtual mapping tests, 1:1 except 0x50xxxxxx -> 0x40xxxxxx  */
        pgtblp = pgtblbuf;
        pgtblp += 0x800 - (((unsigned long)pgtblp)&0x7ff);
        mmudmap((unsigned long *)pgtblp,0x00ff);
        mmudmap_modify((unsigned long *)pgtblp, 0x50000000, 0x40000000, 1, 7);
        /* ITCM virtual mapping test */
        if (itcmsz > 0) {
                /* address of tcmtest_dummy_func in virtual 0x50000000 region
                 *   this will be shadowed by the TCM when it's enabled so depending on if TCM is active
                 *   or not, either the tcmtest_dummy_func or the function in the  */
                test_func_addr = (unsigned long)tcmtest_dummy_func;
                test_func_addr &= 0x00ffffff;
                test_func_addr |= 0x50000000;
                test_func = (funcptr)test_func_addr;
                /* Write test function via ASI so that it overlaps with the test function */
                tcmtest5_copy_itcmfunc(itcmsz, test_func_addr);
                for (i=0; i<5; i++) {
                        /* i=0: TCM disabled
                         * i=1: TCM enabled for MMU-off
                         * i=2: TCM enabled for virtual one-context, same context
                         * i=3: TCM enabled for virtual one-context, different context
                         * i=4: TCM enabled for virtual all contexts
                         * expect to reach TCM for cases 2 and 4, otherwise fall through to dummy function */
                        switch (i) {
                        case 0:  wsysreg(0x48, (test_func_addr & 0xffff0000) | 0x18 | 0); break;
                        case 1:  wsysreg(0x48, (test_func_addr & 0xffff0000) | 0x18 | 1); break;
                        case 2:  wsysreg(0x48, (test_func_addr & 0xffff0000) | 0x18 | 2); break;
                        case 3:  wsysreg(0x48, (test_func_addr & 0xffff0000) | 0x18 | 2 | 0x0100); break;
                        default: wsysreg(0x48, (test_func_addr & 0xffff0000) | 0x18 | 4); break;
                        }
                        j = test_func(100);
                        if (i == 0 && j != (100+3)) fail(21);
                        if (i == 1 && j != (100+3)) fail(22);
                        if (i == 2 && j != 25) fail(23);
                        if (i == 3 && j != (100+3)) fail(24);
                        if (i == 4 && j != 25) fail(25);
                }
        }
        /* DTCM virtual mapping test */
        if (dtcmsz > 0) {
                test_var_addr = (unsigned long)(&testvar);
                test_var_addr &= 0x00ffffff;
                test_var_addr |= 0x50000000;
                testvarp = (volatile unsigned long *)test_var_addr;
                sta0x27(test_var_addr, 99);
                for (i=0; i<5; i++) {
                        switch (i) {
                        case 0:  wsysreg(0x4C, (test_var_addr & 0xffff0000) | 0x78 | 0); break;
                        case 1:  wsysreg(0x4C, (test_var_addr & 0xffff0000) | 0x78 | 1); break;
                        case 2:  wsysreg(0x4C, (test_var_addr & 0xffff0000) | 0x78 | 2); break;
                        case 3:  wsysreg(0x4C, (test_var_addr & 0xffff0000) | 0x78 | 2 | 0x0100); break;
                        default: wsysreg(0x4C, (test_var_addr & 0xffff0000) | 0x78 | 4); break;
                        }
                        j = *testvarp;
                        if (i == 0 && j != 35) fail(26);
                        if (i == 1 && j != 35) fail(27);
                        if (i == 2 && j != 99) fail(28);
                        if (i == 3 && j != 35) fail(29);
                        if (i == 4 && j != 99) fail(30);
                }
        }
        /* Disable TCM and MMU and restore trap table for remaining tests */
        wsysreg(0x48, 0);
        wsysreg(0x4C, 0);
        bcc_set_trap(MYTT_INSTRUCTION_ACCESS_EXCEPTION, NULL);
        bcc_set_trap(MYTT_DATA_ACCESS_EXCEPTION, NULL);
        bcc_set_trap(MYTT_SET_SUPERVISOR, NULL);
        asm volatile ("sta %0, [%%g0] 0x19" : : "r"(0));
        /* region flush of trap table in Icache */
        wsysreg(0x18, ~0xfff);
        wsysreg(0x1c, (get_tbr() & (~0xfff)) | 2);
        /* TCM FT test */
        do_fttest = 0;
        if (((leon5cfg >> 29) & 1) != 0) {
                ftcfg=rsysreg(0x14);
                cft = ftcfg >> 30;
                if (cft != 0) {
                        eitype = rsysreg(0x30) >> 30;
                        if (eitype != 0) { do_fttest = 1;}
                }
        }
        if (do_fttest != 0) {
                /* clear error counters  */
                wsysreg(0x38,0xffffffff);
        }
        for (cemode=0; cemode<2; cemode++) {
                if (cemode == 1 && cft != 1) continue;
                if (cemode==0) correxp=1; else correxp=0;
                if (do_fttest != 0 && itcmsz > 0) {
                        /* Enable ITCM */
                        tcmtest5_copy_itcmfunc(itcmsz, 0);
                        wsysreg(0x48, 0x50000000 | 1 | (3<<3) );
                        wsysreg(0x44, cemode<<8);
                        /* Inject corr error into ITCM */
                        wsysreg(0x30, 1);
                        lda0x26(0);
                        /* A couple of NOPs to ensure code below is not already in pipeline */
                        asm volatile ("nop; nop; nop; nop");
                        /* Execute */
                        if (f(120) != 30) fail(31);
                        /* Check error ctr */
                        errctr = rsysreg(0x38);
                        if (errctr != ((correxp<<15)|(1<<24))) fail(32);
                        /* Clear error ctr */
                        wsysreg(0x38,0xffffffff);
                }
                if (do_fttest != 0 && dtcmsz > 0) {
                        /* Enable DTCM */
                        sta0x27(0, 432);
                        wsysreg(0x4C, 0x50000000 | 1 | (7<<3) );
                        wsysreg(0x44, cemode<<0);
                        /* Inject corr error into ITCM */
                        wsysreg(0x30, 1);
                        lda0x27(0);
                        /* Trigger CE */
                        if (*lptr != 432) fail(33);
                        /* Check error ctr */
                        errctr = rsysreg(0x38);
                        if (errctr != ((correxp<<15)|(1<<22))) fail(34);
                        /* Clear error ctr */
                        wsysreg(0x38,0xffffffff);
                }
        }
}
