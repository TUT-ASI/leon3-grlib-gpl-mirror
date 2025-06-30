#include <report.h>
#include <bcc/ambapp.h>

static const struct report_ops *the_ops = &report_ops_grtestmod;

/*
 * The idea is to select a report backend dynamically. This allows for
 * running the same systest binary in RTL simulation and on hardware.
 *
 * If systest was compiled to use custom report backend, then use it and
 * skip probing (for backwards compatibility).
 * Else, check if if the AHBREP is available and use it.
 * Else, use the stdio printf() and friends and never try to access the
 * (likely non-existing) AHBREP.
 */
int report_start(void)
{
  if (get_pid()) {
    return 0;
  }

#ifndef GRLIB_REPORTDEV_CUSTOM
  unsigned long ahbrep_regs;
  static const unsigned long ioarea = 0xfff00000;

  ahbrep_regs = ambapp_visit(
    ioarea,
    VENDOR_GAISLER,
    GAISLER_GRTESTMOD,
    AMBAPP_VISIT_AHBSLAVE,
    4,
    ambapp_findfirst_fn,
    NULL
  );

  if (!ahbrep_regs) {
    /* No ahbrep, so do it the stdio way. */
    the_ops = &report_ops_stdio;
  } else {
    /* Could inform the backend about ahbrep_regs here. */
  }
#endif

  return the_ops->report_start();
}


/* The following functions just call into the backend. */

int report_end(void) {
  return the_ops->report_end();
}

int report_device(unsigned int dev) {
  return the_ops->report_device(dev);
}

int report_subtest(int subtest) {
  return the_ops->report_subtest(subtest);
}

int fail(int dev) {
  return the_ops->fail(dev);
}

void chkp(int n) {
  the_ops->chkp(n);
}

void report_mem_test(void) {
  the_ops->report_mem_test();
}

