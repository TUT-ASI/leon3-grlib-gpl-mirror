
#include "testmod.h"

static unsigned long lda0x20(unsigned long addr)
{
        unsigned long l;
        asm volatile ("lda [%1] 0x20, %0" : "=r"(l) : "r"(addr));
        return l;
}

static void sta0x20(unsigned long addr, unsigned long data)
{
        asm volatile ("sta %0, [%1] 0x20" : : "r"(data),"r"(addr));
}

static void load_fpregs(unsigned long addr)
{
        asm volatile (
                      "ld [%0+0x00], %%f0\n"
                      "ld [%0+0x04], %%f1\n"
                      "ld [%0+0x08], %%f2\n"
                      "ld [%0+0x0C], %%f3\n"
                      "ld [%0+0x10], %%f4\n"
                      "ld [%0+0x14], %%f5\n"
                      "ld [%0+0x18], %%f6\n"
                      "ld [%0+0x1C], %%f7\n"
                      "ld [%0+0x20], %%f8\n"
                      "ld [%0+0x24], %%f9\n"
                      "ld [%0+0x28], %%f10\n"
                      "ld [%0+0x2C], %%f11\n"
                      "ld [%0+0x30], %%f12\n"
                      "ld [%0+0x34], %%f13\n"
                      "ld [%0+0x38], %%f14\n"
                      "ld [%0+0x3C], %%f15\n"
                      "ld [%0+0x40], %%f16\n"
                      "ld [%0+0x44], %%f17\n"
                      "ld [%0+0x48], %%f18\n"
                      "ld [%0+0x4C], %%f19\n"
                      "ld [%0+0x50], %%f20\n"
                      "ld [%0+0x54], %%f21\n"
                      "ld [%0+0x58], %%f22\n"
                      "ld [%0+0x5C], %%f23\n"
                      "ld [%0+0x60], %%f24\n"
                      "ld [%0+0x64], %%f25\n"
                      "ld [%0+0x68], %%f26\n"
                      "ld [%0+0x6C], %%f27\n"
                      "ld [%0+0x70], %%f28\n"
                      "ld [%0+0x74], %%f29\n"
                      "ld [%0+0x78], %%f30\n"
                      "ld [%0+0x7C], %%f31\n"
                      : : "r"(addr));
}

static void store_fpregs(unsigned long addr)
{
        asm volatile (
                      "st %%f0,  [%0+0x00]\n"
                      "st %%f1,  [%0+0x04]\n"
                      "st %%f2,  [%0+0x08]\n"
                      "st %%f3,  [%0+0x0C]\n"
                      "st %%f4,  [%0+0x10]\n"
                      "st %%f5,  [%0+0x14]\n"
                      "st %%f6,  [%0+0x18]\n"
                      "st %%f7,  [%0+0x1C]\n"
                      "st %%f8,  [%0+0x20]\n"
                      "st %%f9,  [%0+0x24]\n"
                      "st %%f10, [%0+0x28]\n"
                      "st %%f11, [%0+0x2C]\n"
                      "st %%f12, [%0+0x30]\n"
                      "st %%f13, [%0+0x34]\n"
                      "st %%f14, [%0+0x38]\n"
                      "st %%f15, [%0+0x3C]\n"
                      "st %%f16, [%0+0x40]\n"
                      "st %%f17, [%0+0x44]\n"
                      "st %%f18, [%0+0x48]\n"
                      "st %%f19, [%0+0x4C]\n"
                      "st %%f20, [%0+0x50]\n"
                      "st %%f21, [%0+0x54]\n"
                      "st %%f22, [%0+0x58]\n"
                      "st %%f23, [%0+0x5C]\n"
                      "st %%f24, [%0+0x60]\n"
                      "st %%f25, [%0+0x64]\n"
                      "st %%f26, [%0+0x68]\n"
                      "st %%f27, [%0+0x6C]\n"
                      "st %%f28, [%0+0x70]\n"
                      "st %%f29, [%0+0x74]\n"
                      "st %%f30, [%0+0x78]\n"
                      "st %%f31, [%0+0x7C]\n"
                      : : "r"(addr) : "memory");
}

void fputest5(void)
{
        unsigned long rfi[32],rfo[32];
        int fpuver;
        int i;
        report_subtest(FPU_TEST+(get_pid()<<4));
        /* Check which FPU that we have */
        fpuver = lda0x20(0x90) >> 29;
        if (fpuver == 4) {
                /* GRFPU5 */
                /* Put FPU in GRFPU compatibility mode and run normal grfpu_test */
                sta0x20(0x90, 0xA8);
                grfpu_test5(0);
                /* Put FPU back into IEEE compatible mode for remaining test */
                sta0x20(0x90, 0x55);
        }
        grfpu_test5(1);
        /* Test reading and writing the registers through the ASI 0x20 interface */
        for (i=0; i<32; i++) rfi[i] = i*7;
        load_fpregs((unsigned long)rfi);
        for (i=0; i<32; i++) rfo[i] = lda0x20(4*i);
        for (i=0; i<32; i++) if (rfi[i] != rfo[i]) fail(128);
        for (i=0; i<32; i++) rfi[i] = i*13;
        for (i=0; i<32; i++) sta0x20(4*i,rfi[i]);
        store_fpregs((unsigned long)rfo);
        for (i=0; i<32; i++) if (rfi[i] != rfo[i]) fail(129);
        fpu5_trapcycle_setup();
        /* Do all stages of exception in SW (dry run) */
        if (fpu5_trapcycle(7)) fail(130);
        /* Go through stages of exception first in SW, then recover with debug i/f */
        if (fpu5_trapcycle(3)) fail(131);
        if (fpu5_trapcycle(1)) fail(132);
        if (fpu5_trapcycle(0)) fail(133);
        /* Go into stages of exception with debug i/f, then complete in SW */
        if (fpu5_trapcycle(4)) fail(134);
        if (fpu5_trapcycle(6)) fail(135);
        /* For GRFPU5, test loading the DFQ with up to 8 entries */
        if (fpuver == 4) {
                for (i=2; i<9; i++) {
                        if (fpu5_multidfq(i,0)) fail(136+4*(i-2));
                        if (fpu5_multidfq(i,1)) fail(136+4*(i-2)+1);
                        if (fpu5_multidfq(i,2)) fail(136+4*(i-2)+2);
                        if (fpu5_multidfq(i,3)) fail(136+4*(i-2)+3);
                }
        }
}

