#include "leon3.h"
#include "ftlib.h"
#include "ahbstat.h"
#include "ftmctrl.h"
#include "testmod.h"

static volatile int dexcn;
static volatile int stest;
static volatile int dtest;
static volatile int xtest;
static volatile long long ytest, ddtmp;
static volatile int xarr[2];
static volatile char *ztest;
static volatile int *yptr;

static struct ahbstat *ahbr;
static struct ftmctrl *ftmr;

static dblerr(int *p, int addr)
{
        int tmp2,tmp3,tmp4;
	asm volatile (
	"ld	[%4 + 0x08], %2;"
	"andn	%2, 0x0FF, %1;"
	"or	%1, 0x80C, %1;"
	"set	3, %0;"
	"st	%1, [%4 + 0x08];"
	"st	%0, [%3];"
	"st	%2, [%4 + 0x08];"
        : "=&r"(tmp2), "=&r"(tmp3), "=&r"(tmp4)
        : "r"(p), "r"(addr)
        : "memory"
	);
/*
	asm(
	"ld	[%o1 + 0x08], %o4;"
	"or 	%o4, 0x400, %o3;"
	"st	%o3, [%o1 + 0x08];"
	"ld	[%o0], %o2;"
	"ld	[%o1 + 0x08], %o3;"
	"xor	%o2, 3, %o2;"
	"andn	%o3, 0x400, %o3;"
	"or 	%o3, 0x800, %o3;"
	"st	%o3, [%o1 + 0x08];"
	"st	%o2, [%o0];"
	"st	%o4, [%o1 + 0x08];"
	);
*/
}

asm(".align 32");
asm(
"	.global _skipn, dexcn, _reex;"
"_skipn: set	dexcn, %l4;"
"	ld	[%l4], %l5;"
"	subcc	%l5, 1, %l5;"
"	st	%l5, [%l4];"
"	bl	dexcfail;"
"	nop;"
"	jmpl	%l2, %g0;"
"	rett	%l2 + 4 ;"
"_reex: set	dexcn, %l4;"
"	ld	[%l4], %l5;"
"	subcc	%l5, 1, %l5;"
"	st	%l5, [%l4];"
"	bl	dexcfail;"
"	nop;"
"	jmpl	%l1, %g0;"
"	rett	%l2;"
"dexcfail: ta	0;"
);

/* will write specified data and checkbits to given address */
ftinsdata(int data, int cb, int *addr)
{
        /* %o0 -> 3, %o1 -> 4, %o2 -> 5, %o3 -> 0, %o4 -> 1, %o5 -> 2 */
        int tmp3,tmp4,tmp5;
        asm volatile (
        "set	0x80000000, %2;"
        "ld	[%2 + 0x08], %0;"
        "or 	%0, 0x800, %1;"
        "andn    %1, 0x0ff, %1;"
        "or	%4, %1, %1;"
        "st	%1, [%2 + 0x08];"
        "st	%3, [%5];"
        "st	%0, [%2 + 0x08];"
        : "=&r"(tmp3),"=&r"(tmp4),"=&r"(tmp5)
        : "r"(data), "r"(cb), "r"(addr)
        : "memory");
}

static int bch_edac_test(int paddr, int pirq);

static __attribute__((noinline)) dumfunc()
{
	asm("nop; nop; nop;");
}

static int rs_edac_test(int paddr, int pirq)
{
	int tmp,i;

	/* test single-bit errors in all positions */

	stest = dtest = xtest = 0; 
	dblerr((int *) &dtest, paddr); dblerr((int *) &xtest, paddr);
	ftmr->memcfg4 |= 0x10000 ^ 0x0; tmp = stest; stest = 1;

	if ((stest != 0) || (ahbr->failaddr != (int) &stest) ||
	   (ahbr->memstatus != 0x302))
	{
		fail(1);
	}

	for (i=1;i<32;i++) { 
		stest = 1 << i; 
		if (stest != 0) break;
	}
	if ((i!=32) || (ahbr->failaddr != (int) &stest) || 
		(ahbr->memstatus != 0x302))
	{
		fail(2);
	}

	/* insert single-error in instructions */
	ftmr->memcfg3 &= ~0x0ff; ftmr->memcfg3 |= 0x06e;
	tmp = *((int *) dumfunc); *((int *) dumfunc) = tmp ^ 1;
	ftmr->memcfg3 &= ~0x0ff; ftmr->memcfg3 |= 0x00c;
	
	/* check that FAR is not loaded on second error */

	ftmr->memcfg3 &= ~0x800; dexcn = 1; tmp = dtest;
	if ((ahbr->failaddr != (int) &stest) || (ahbr->memstatus != 0x302) ||
		(dexcn != 0)) { fail(3); }

	/* clear memory status register and provoke double error */
	ahbr->memstatus = 0; dexcn = 1; tmp = xtest;
	if ((ahbr->failaddr != (int) &xtest) || (ahbr->memstatus != 0x102) ||
		(dexcn != 0)) fail(4);

	/* check that FAR is not changed */
	dexcn = 1; tmp = dtest;
	if ((ahbr->failaddr != (int) &xtest) || (ahbr->memstatus != 0x102) ||
		(dexcn != 0)) fail(5);

	/* check errors during byte write */
	ztest = (char *) &dtest; dexcn = 1;
	ahbr->memstatus = 0; ztest[0] = 4;
	if ((ahbr->failaddr != (int) &dtest) || (ahbr->memstatus != 0x180) ||
		(pend_irq(pirq) == 0)) { fail(6); }
	clear_irq(pirq);
	ftmr->memcfg3 &= ~(1 << RAMEDAC_EN_BIT);	/* disable edac */
	if (dtest != 3) fail(7);/* check that write cycle was aborted */
	ftmr->memcfg3 |= (1 << RAMEDAC_EN_BIT);	/* enable edac */

	/* single-error correction in byte write, no cerror */
	ztest = (char *) &stest;
	stest = 0; ahbr->failaddr = 0;
	ftmr->memcfg4 = 0x10000; stest = 1^stest; ftmr->memcfg3 &= ~0x800;
	ahbr->memstatus = 0;  ((char *) &stest)[2] = 5;
  // Check for no error in memstatus
	if ((stest!=0x500) || ((ahbr->memstatus & 0x300) != 0))
		fail(8);

	/* check load/store double exceptions */
	ytest = 0; ahbr->failaddr = 0; yptr = (int *) &ytest; dblerr((int *)yptr, paddr);
	ahbr->memstatus = 0; dexcn = 1; ddtmp = 0;
	ddtmp = ytest;	/* read exception on first word */
	if ((ahbr->failaddr != (int) &ytest) || (ahbr->memstatus != 0x102))
		fail(9);

	ytest = 0; ahbr->failaddr = 0; dblerr((int *)&yptr[1], paddr);
	ahbr->memstatus = 0; dexcn = 1;
	ddtmp = ytest;	/* exception on second word */
	if ((ahbr->failaddr != (int) &yptr[1]) || (ahbr->memstatus != 0x102))
		fail(10);

	/* EDAC error in instructions */
	ahbr->memstatus = 0; dexcn = 1; 
	dumfunc();
	if ((ahbr->failaddr != (int) dumfunc) || (ahbr->memstatus != 0x102))
		fail(11);
}

static int edac_test(int paddr, int pirq)
{
	int tmp,i;


	/* skip test if edac disabled */
	if (!((ftmr->memcfg3 >> RAMEDAC_EN_BIT) & 1))
		return(0);	

	report_subtest(MCTRL_EDAC);
	dexcn = 0;
	ahbr->memstatus = 0;			/* initialise MSTAT */
	cache_disable();
	clear_all_irq();

	if (ftmr->memcfg3 >> RSEDAC_EN_BIT)
	    rs_edac_test(paddr, pirq);
	else
	    bch_edac_test(paddr, pirq);

	flush();
	cache_enable();
}

static int bch_edac_test(int paddr, int pirq)
{
	int tmp,i;

	/* test single-bit errors in all positions */

	stest = dtest = xtest = 0; 
	dblerr((int *) &dtest, paddr); dblerr((int *) &xtest, paddr);
	ftmr->memcfg3 |= 0x80c; tmp = stest; stest = 1;

	if ((stest != 0) || (ahbr->failaddr != (int) &stest) ||
	   (ahbr->memstatus != 0x302))
	{
		fail(1);
	}

	for (i=1;i<32;i++) { 
		stest = 1 << i; 
		if (stest != 0) break;
	}
	if ((i!=32) || (ahbr->failaddr != (int) &stest) || 
		(ahbr->memstatus != 0x302))
	{
		fail(2);
	}

	/* insert single-error in instructions */
	ftmr->memcfg3 &= ~0x0ff; ftmr->memcfg3 |= 0x06e;
	tmp = *((int *) dumfunc); *((int *) dumfunc) = tmp ^ 1;
	ftmr->memcfg3 &= ~0x0ff; ftmr->memcfg3 |= 0x00c;
	
	/* check that FAR is not loaded on second error */

	ftmr->memcfg3 &= ~0x800; dexcn = 1; tmp = dtest;
	if ((ahbr->failaddr != (int) &stest) || (ahbr->memstatus != 0x302) ||
		(dexcn != 0)) { fail(3); }

	/* clear memory status register and provoke double error */
	ahbr->memstatus = 0; dexcn = 1; tmp = xtest;
	if ((ahbr->failaddr != (int) &xtest) || (ahbr->memstatus != 0x102) ||
		(dexcn != 0)) fail(4);

	/* check that FAR is not changed */
	dexcn = 1; tmp = dtest;
	if ((ahbr->failaddr != (int) &xtest) || (ahbr->memstatus != 0x102) ||
		(dexcn != 0)) fail(5);

	/* check errors during byte write */
	ztest = (char *) &dtest; dexcn = 1;
	ahbr->memstatus = 0; ztest[0] = 4;
	if ((ahbr->failaddr != (int) &dtest) || (ahbr->memstatus != 0x180) ||
		(pend_irq(pirq) == 0)) { fail(6); }
	clear_irq(pirq);
	ftmr->memcfg3 &= ~(1 << RAMEDAC_EN_BIT);	/* disable edac */
	if (dtest != 3) fail(7);/* check that write cycle was aborted */
	ftmr->memcfg3 |= (1 << RAMEDAC_EN_BIT);	/* enable edac */

	/* single-error correction in byte write, no cerror */
	ztest = (char *) &stest;
	stest = 0; ahbr->failaddr = 0;
	ftmr->memcfg3 |= 0x800; stest = 1^stest; ftmr->memcfg3 &= ~0x800;
	ahbr->memstatus = 0;  ((char *) &stest)[2] = 5;
  // Check for no error in memstatus
	if ((stest!=0x500) || ((ahbr->memstatus & 0x300) != 0))
		fail(8);

	/* check load/store double exceptions */
	ytest = 0; ahbr->failaddr = 0; yptr = (int *) &ytest; dblerr((int *)yptr, paddr);
	ahbr->memstatus = 0; dexcn = 1; ddtmp = 0;
	ddtmp = ytest;	/* read exception on first word */
	if ((ahbr->failaddr != (int) &ytest) || (ahbr->memstatus != 0x102))
		fail(9);

	ytest = 0; ahbr->failaddr = 0; dblerr((int *)&yptr[1], paddr);
	ahbr->memstatus = 0; dexcn = 1;
	ddtmp = ytest;	/* exception on second word */
	if ((ahbr->failaddr != (int) &yptr[1]) || (ahbr->memstatus != 0x102))
		fail(10);

	/* EDAC error in instructions */
	ahbr->memstatus = 0; dexcn = 1; 
	dumfunc();
	if ((ahbr->failaddr != (int) dumfunc) || (ahbr->memstatus != 0x302))
		fail(11);
}
	
static volatile short a[2] = {1,0};
static volatile char x[4] = {0,0,1,2};
extern void _skipn(void), _reex(void);
extern void exceptionHandler(unsigned char ex_num, void (*ex_add)(void), int tbr, int *old);
extern void restore_trap(unsigned char ex_num, int tbr, int *old);
static int oldt1[4], oldt2[4], oldt3[4];

mctrl_test(int paddr, int saddr, int irq)
{

    volatile int wtest = 0;
    int i;

    ahbr = (struct ahbstat *) saddr;
    ftmr = (struct ftmctrl *) paddr;

    report_device(0x01054000);
    exceptionHandler( 0x09, _skipn, rdtbr() & ~0xfff, oldt1);
    exceptionHandler( 0x2b, _reex, rdtbr() & ~0xfff, oldt2);
    exceptionHandler( 0x01, _skipn, rdtbr() & ~0xfff, oldt3);

#if 0
    if (0) {
/* test I/O bus exception */

	if (!(lr->leonconf & 0x40)) return(0);
	report(MEM_TEST);

	ftmr->memcfg1 |= (0x23 << 20); /* enable BEXCN signal */
	dexcn = 1; ahbr->failaddr = 0; ahbr->memstatus = 0;
	inb(80,0); /* cause read exception */
	if ((ahbr->failaddr != (IOAREA + 80)) || (ahbr->memstatus != 0x180) ||
		(dexcn != 0)) { fail(1); }
	dexcn = 1; ahbr->failaddr = 0; ahbr->memstatus = 0;
	inb(72,0); /* cause read exception */
	if ((ahbr->failaddr != (IOAREA + 72)) || (ahbr->memstatus != 0x180) ||
		(dexcn != 0)) { fail(2); }
	ahbr->failaddr = 0; ahbr->memstatus = 0; dexcn = 1;
	outb(80,0); /* cause write exception */
	if ((ahbr->failaddr != (IOAREA + 80)) || (ahbr->memstatus != 0x100) ||
		(dexcn != 0)) { fail(3); }
	ahbr->failaddr = 0; ahbr->memstatus = 0; dexcn = 1;
	outb(72,0); /* cause write exception */
	if ((ahbr->failaddr != (IOAREA + 72)) || (ahbr->memstatus != 0x100) ||
		(dexcn != 0)) { fail(4); }

    }

#endif

/* do some simple byte/half-word checking */

	report_subtest(MCTRL_BYTE);
	a[0] = 0x12; a[1] = 0x23;
	if (*(volatile int *)a != 0x00120023) fail(10);
	x[0] = 0x12; x[1] = 0x34; x[2] = 0x56; x[3] = 0x78;
	if (*(int *)x != 0x12345678) fail(11);

	edac_test(paddr, irq);
    restore_trap( 0x09, rdtbr() & ~0xfff, oldt1);
    restore_trap( 0x2b, rdtbr() & ~0xfff, oldt2);
    restore_trap( 0x01, rdtbr() & ~0xfff, oldt3);

#if 0
/* write protection test */

	if (lr->leonconf & 0x3) {
		report(WP_TEST);
		lr->cachectrl = cache_disable();
//		lr->writeprot2 = 0;
//		lr->writeprot1 = 0xc0007fff | (((int)&wtest) & 0x3fff8000);
		clear_irq(irq);

		/* word write error */
		dexcn = 1; ahbr->failaddr = 0; ahbr->memstatus = 0;
		wtest = 1;
		if ((ahbr->failaddr != (int) &wtest) || (ahbr->memstatus != 0x102) ||
			(wtest == 1) || (dexcn != 0) || ((lr->irqpend & 2) == 0)) { fail(5); }
		ahbr->failaddr = 0; ahbr->memstatus = 0; lr->irqclear = 2; 

		/* byte write error */
		dexcn = 1; lr->failaddr = 0; lr->memstatus = 0;
		* (char *) &wtest = 1;
		if ((lr->failaddr != (int) &wtest) || (lr->memstatus != 0x100) ||
			(wtest == 1) || (dexcn != 0) || ((lr->irqpend & 2) == 0)) { fail(6); }
		lr->failaddr = 0; lr->memstatus = 0; lr->irqclear = 2; 

		lr->writeprot2 = 0x80007fff | (((int)&wtest) & 0x3fff8000);
		wtest = 1;
		if (lr->irqpend & 2) { fail(7); }
		lr->writeprot2 = 0;
		lr->writeprot1 ^= 0x00010000;
		wtest = 1;
		if ((lr->irqpend & 2)) { fail(8); }
		lr->writeprot1 = 0; dexcn = 1; lr->writeprot2 = 0x80007fff;
		wtest = 1;
		lr->writeprot2 = 0;
		if ((lr->failaddr != (int) &wtest) || (lr->memstatus != 0x102) ||
			((lr->irqpend & 2) == 0)) { fail(9); }
		flush();
		cache_enable(); 
		lr->failaddr = 0; lr->memstatus = 0; lr->irqclear = 2; 

	}
#endif
}

/*
static int line1(int x);

static wp_test()
{
	int i, wpn;

	dexcn = 1;
	asm("wr	%g0, %g0, %asr24");
	if (dexcn == 0) return(0);
	asm("wr	%g0, %g0, %asr25");
	asm("wr	%g0, %g0, %asr26");
	asm("wr	%g0, %g0, %asr27");
	asm("wr	%g0, %g0, %asr28");
	asm("wr	%g0, %g0, %asr29");
	asm("wr	%g0, %g0, %asr30");
	asm("wr	%g0, %g0, %asr31");
	report(WATCH_TEST);

	dexcn = 0;
	stest = 0;
	line1(stest);	
	dexcn = 3;
	set_asr25(0xfffffffc);
	set_asr24(1 | (~3 & (int)line1));
	line1(*(int *)line1);	
	if (dexcn != 2) fail(1);
	set_asr25(0xfffffffe);
	set_asr24((int)&stest);
	stest = 0;
	if (dexcn != 2) fail(2);
	stest += 1;
	if (dexcn != 1) fail(3);
	set_asr25(0xfffffffd);
	stest = 0;
	if (dexcn != 0) fail(4);
	set_asr25(0xfffffffc);
}

*/
