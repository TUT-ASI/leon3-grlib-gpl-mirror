#include "config.h"

main()

{
  report_start();
  // Note: Do NOT 'greth_test' in immediately after or together with 'greth_test' test
  base_test();
  #ifdef CONFIG_GRETH_ENABLE
  // Note: To run GRETH test please comment out the 'base_test()' first.
  //greth_test(0x800c0000);
  #endif
  report_end();
}
