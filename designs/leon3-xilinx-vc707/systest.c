#include "config.h"

main()

{

/*
unsigned long* const memptr = (unsigned long*) 0x40000000;
unsigned long memory;
*memptr = 0x87654321;
memory = *memptr; 
*/

  report_start();
  base_test();
  #ifdef CONFIG_GRETH_ENABLE
  /* Ethernet Tests - EDCL must finish... */
  greth_test(0x800c0000);
  #endif
  /* FCM Connector Test */
  #ifdef CONFIG_GRETH_FMC_MODE
  greth_test(0xA0000000);
  greth_test(0xA0001000);
  greth_test(0xA0002000);
  greth_test(0xA0003000);
  greth_test(0xA0004000);
  greth_test(0xA0005000);
  greth_test(0xA0006000);
  greth_test(0xA0007000);
  #endif
  report_end();
}
