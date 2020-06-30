/*
 * Tests related to clock gating.
 *
 * This file is part of GRLIB system test software.
 * Copyright (c) 2012 Aeroflex Gaisler AB
 *
 */

#include "testmod.h"
#include "gptimer.h"
#include "leon3.h"
#include "irqmp.h"


static cgtest_irqhandler(int irq) { };

/*
 * Test power-down mode directly after FPU instruction has been issued
 * 
 * Arguments:
 * imp_base - base address of interrupt controller
 * gpt_base - base address of timer unit
 * irq      - interrupt of first timer of timer unit
 * stfsr    - Include store %fsr instruction before power down
 *
 */
void pwd_fpu_test(int imp_base, int gpt_base, int irq, int stfsr)
{
   struct gptimer *lr = (struct gptimer *)gpt_base;
   unsigned int tmp;
   double f0 = 1.0, f1 = 2.0, fres = 0;

   report_device(0x0102c000);
   
   /* Check if we have a FPU */
   tmp = xgetpsr();
   setpsr(tmp | (1 << 12));
   tmp = xgetpsr();
   if (!(tmp & (1 <<12)))
      fail(1);

   if (!irqmp_base)
      irqmp_base = (struct irqmp*)imp_base;
   
   catch_interrupt(cgtest_irqhandler, irq);
   init_irqmp(irqmp_base);
   irqmp_base->irqmask = 1 << irq; /* unmask interrupt */
   lr->scalerload = 31;
   lr->scalercnt = 31;
   lr->timer[0].reload = 15;
   lr->timer[0].control = 0xd;
   
   /* Start floating point division. Need to use asm,
    * otherwise we are bound to get a store inst. that
    * we don't want.
    * nops are inserted to get the FPU op to start before
    * the processor goes into power-down.
    * Note: This case is intended to demonstrate that the FPU
    * op will complete when the processor resumes. If fdiv and
    * nop end up on different cache lines this may not show.
    */
   if (!stfsr) {
      asm volatile("fdivd %1,%2,%0\n\t"
                   "nop\n\t"
                   "wr %%g0, %%g0, %%asr19\n\t" /* power-down */
                   : "=f" (fres) : "f"(f0), "f"(f1));
   } else {
      asm volatile("fdivd %2,%3,%0\n\t"
                   "st %%fsr, %1\n\t"
                   "nop\n\t"
                   "wr %%g0, %%g0, %%asr19\n\t" /* power-down */
                   : "=f" (fres), "=m" (tmp) : "f"(f0), "f"(f1));
   }

   if (fres != 0.5)
      fail(3);
}

/*
 * Use two processors where one issues a FP instruction and then
 * goes into power down. The other processor keeps running. This 
 * prevents the FPU from being gated off in systems with shared
 * FPU - and can lead to processor 0 freezing when the FPU
 * completes the operation while processor 0 is gated off.
 *
 * Arguments:
 * imp_base - base address of interrupt controller
 * gpt_base - base address of timer unit
 * irq      - interrupt of first timer of timer unit
 * stfsr    - Include store %fsr instruction before power down
 *
 * When stfsr is set to 1 the processor should not freeze.
 *
 * This test should be the first, and only, test function called.
 *
 */
static volatile int cgflag = 0;

void pwd_shared_fpu_test(int imp_base, int gpt_base, int irq, int stfsr)
{   
   if (get_pid()) { 
      cgflag = 1;
      while(cgflag != 2); /* Processor 1 waits here */
   } else {
      if (!irqmp_base)
         irqmp_base = (struct irqmp*)imp_base;

      /* Start processor 1 */
      irqmp_base->mpstatus = 2;
      
      while (!cgflag) /* Wait for processor 1 */
         ;
      
      pwd_fpu_test(imp_base, gpt_base, irq, stfsr);

      cgflag = 2; /* Release processor 2 */
   }
}
