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

void regfltest(unsigned long freeaddr)
{
        unsigned long iccfg, dccfg;
        unsigned long iways, isets, iwaysize, iclsizep, iclsize, itagmask;
        unsigned long dways, dsets, dwaysize, dclsizep, dclsize, dtagmask;
        int w,s,a,d,r,ra,rv,ev;
        int testcase;
        unsigned flmask, fladdr;
        int nrepli,nrepld;
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
                nrepli = nrepld = 0;
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
                                        if (ev != rv) fail(61+(testcase<<3));
                                }
                        }
                }
                if (nrepli > 24) fail(62+(testcase<<3));
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
                                        if (ev != rv) fail(64+(testcase<<3));
                                }
                        }
                }
                if (nrepld > 8) fail(65+(testcase<<3));
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

      if (((cachectrl >> ITE_BIT) & 3) == 0) { // skip test during err. injection
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
        int cemode, correxp;
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
                if (errctr != ((correxp<<15)|(1<<8))) fail(128);
                wsysreg(0x38,~0);
                line0();
                errctr = rsysreg(0x38);
                if (errctr != 0) fail(129);
                idata_inject(&line0,1,iwaysize,itagmask);
                line0();
                errctr = rsysreg(0x38);
                if (errctr != ((correxp<<15)|(1<<6))) fail(130);
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
                wsysreg(0x38,~0);
                regld(&l);
                ddata_inject(&l,1,dwaysize,dtagmask);
                v = regld(&l);
                errctr = rsysreg(0x38);
                if (errctr != ((correxp<<15)|(1<<0)) || v != 0) fail(133);
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
