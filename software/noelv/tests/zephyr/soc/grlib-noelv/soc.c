/*
 * Copyright (c) 2019, Cobham Gaisler AB
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <kernel.h>

/* tickless kernel is not supported */
u32_t z_clock_elapsed(void)
{
        return 0;
}

void __attribute__((noreturn)) tohost_exit(uintptr_t code)
{      
  //if (code != 0) ERROR(code);
  //tohost = (code << 1) | 1;
  __asm__ volatile("nop");
  __asm__ volatile("nop"); 
  //END_SIM();
  __asm__ volatile("ebreak");
  while (1);
}

FUNC_NORETURN __weak void z_arch_system_halt(unsigned int reason)
{
        ARG_UNUSED(reason);

        (void)z_arch_irq_lock();
	/* Custom to NOELV */
	tohost_exit(reason);
}

void z_arch_cpu_idle(void)
{
  /* Only for verification in simulation */
  tohost_exit(0);
}

