
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

leon5_test(int domp, volatile int *irqmp, int mtest)
{
	int tmp, i;

	if (!get_pid()) report_device(0x010BA000);
	if (domp) mptest_start(irqmp);	
	report_subtest(REGFILE+(get_pid()<<4));
	if (regtest()) fail(1);
	report_subtest(CASA_TEST+(get_pid()<<4));
	casa_test();
	multest();
	divtest();
        /* FPU test uses global variables currently, avoid concurrently
         * running by using a simple spinlock */
        mp_lock(&fpu_lock);
	fputest5();
        mp_unlock(&fpu_lock);
	if (mtest) cramtest();
	cachetest5();
	if ((*mpfunc[get_pid()])) mpfunc[get_pid()](get_pid());
        /* MMU test uses global variables */
        mp_lock(&mmu_lock);
	mmu_test();
        mp_unlock(&mmu_lock);
	if (domp) mptest_end(irqmp);
}
