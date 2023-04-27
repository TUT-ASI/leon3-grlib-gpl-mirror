
#include "testmod.h"

//void (*mpfunc[16])(int index);

#define ASR17_LDDEL (1 << 12)

static unsigned long do_casa(unsigned long *p, unsigned long cmp, unsigned long swp)
{
        asm volatile ("casa [%1] 0xA, %2, %0\n" : "+r"(swp) : "p"(p), "r"(cmp) : "memory");
        return swp;
}

static void memclob(void)
{
        asm volatile ( "" ::: "memory" );
}

static void mp_lock(unsigned long *p)
{
        while (do_casa(p,0,1) != 0) {
                while (*p != 0) {
                        memclob();
                }
        }
}

static void mp_unlock(unsigned long *p)
{
        *p = 0;
        memclob();
}

static unsigned long fpu_lock=0,mmu_lock=0;

static unsigned long lda0x02(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x02, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x02(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x02" : : "r"(data),"r"(addr));
}

int wcomb_test_main(unsigned long long *bufptr, int len);

static void wcomb_test(void)
{
        unsigned long l5cfg;
        unsigned long long wcomb_buf[11];
        int al,l;
        report_subtest(((get_pid()) << 4) | 1);
        /* Get current LEON5 configuration register state, ensure wcomb is
         * set during test */
        l5cfg = lda0x02(0x10);
        if ((l5cfg & 0x800) == 0) {
                sta0x02(0x10, l5cfg | 0x800);
                memclob();
        }
        /* Run once to warm up the I-cache */
        if (wcomb_test_main(wcomb_buf, 8) != 0) fail(0);
        /* Test different lengths and starting point alignments */
        for (al=0; al<4; al++) {
                for (l=1; l<8; l++) {
                        if (wcomb_test_main(wcomb_buf+al, l) != 0) fail(al*16+l);
                }
        }
        /* Restore LEON5 config reg */
        if ((l5cfg & 0x800) == 0) {
                sta0x02(0x10, l5cfg);
                memclob();
        }
}

leon5_test(int domp, volatile int *irqmp, int mtest)
{
	int tmp, i;
	/* if (!get_pid())  L2C_stripe_cfg(); */
	if (!get_pid()) report_device(0x010BA000);
	if (domp) mptest_start(irqmp);
	tcmtest5_prepare();
	report_subtest(REGFILE+(get_pid()<<4));
	if (regtest()) fail(1);
	report_subtest(CASA_TEST+(get_pid()<<4));
	casa_test();
	multest();
	divtest();
	fputest5();
	if (mtest) cramtest();
	cachetest5();
	tcmtest5();
        wcomb_test();
	if ((*mpfunc[get_pid()])) mpfunc[get_pid()](get_pid());
        /* MMU test uses global variables */
        mp_lock(&mmu_lock);
	mmu_test();
        mp_unlock(&mmu_lock);
	if (domp) mptest_end(irqmp);
}
