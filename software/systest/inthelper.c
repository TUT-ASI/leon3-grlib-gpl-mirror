#include <inthelper.h>
#include <bcc/bcc_param.h>
#include <bcc/bcc.h>

void mask_all_interrupts(void)
{
  for (int i = 0; i < 32; i++) {
    bcc_int_mask(i);
  }
}


#if defined(__riscv)

void clear_all_interrupts(void)
{
  /* NCC does not have a function to clear interrupt source. */
}

#else

void clear_all_interrupts(void)
{
  for (int i = 0; i < 32; i++) {
    bcc_int_clear(i);
  }
}


/*
 * The IRQMP ilevel register must be initialized for the IRQMP to function
 * correctly. The RTL does not reset ilevel. BCC assumes the boot loader has
 * initialized ilevel as part of a system configuration and/or a policy to not
 * touch registers if not strictly needed. GRLIB systest uses a "distributed"
 * boot loader solution (find prom.S). So lets init ilevel just prior to
 * main().
 */
#include <bcc/regs/irqmp.h>
void __bcc_init70(void) {
  volatile struct irqmp_regs *regs = (void *) __bcc_int_handle;
  if (regs == NULL) {
    return;
  }
  regs->ilevel = 0;
}

#endif

