#include <stdio.h>
#include "report.h"

#include "apuart.h"
#include "i2cmst.h"
#include "i2c.h"
#include "spimctrl.h"
#include "spictrl.h"
#include "grcanfd.h"
#include "gptimer.h"
#include "griommu.h"
#include "greth.h"
#include "l2c.h"
#include "l2capi.h"

#ifndef CONSOLE_DEBUG
#define CONSOLE_DEBUG 1 // Set to 0 to disable the following printf statements
#endif
// Default base addresses
#ifndef APBUART_ADDR_SYSTEST
#define APBUART_ADDR_SYSTEST 0xfc001000ULL // De-RISC
#endif
#ifndef SPIMCTRL_ADDR_SYSTEST
#define SPIMCTRL_ADDR_SYSTEST 0xfff90000ULL // Generic
#endif
#ifndef SPICTRL_ADDR_SYSTEST
#define SPICTRL_ADDR_SYSTEST 0xfc100a00ULL // Generic: 0xfc000d00 | De-RISC: 0xfc100a00
#endif
#ifndef I2C_MST_ADDR_SYSTEST
#define I2C_MST_ADDR_SYSTEST 0xfc000c00ULL // Generic
#endif
#ifndef I2C_SLV_ADDR_SYSTEST
#define I2C_SLV_ADDR_SYSTEST 0xfc000e00ULL // Generic
#endif
#ifndef GRCANFD_ADDR_SYSTEST
#define GRCANFD_ADDR_SYSTEST 0xfc000c00ULL // (no little endian support yet)
#endif
#ifndef GPTIMER_ADDR_SYSTEST
#define GPTIMER_ADDR_SYSTEST 0xfc000000ULL // De-RISC
#endif
#ifndef GRIOMMU_ADDR_SYSTEST
#define GRIOMMU_ADDR_SYSTEST 0xfffd0000ULL // De-RISC
#endif
#ifndef GRETH_ADDR_SYSTEST
#define GRETH_ADDR_SYSTEST 0xfc101000ULL // De-RISC
#endif
#ifndef L2C_ADDR_SYSTEST
#define L2C_ADDR_SYSTEST 0xff000000ULL // De-RISC: 0xff000000ULL
#endif
// Default PIRQ
#ifndef SPICTRL_PIRQ
#define SPICTRL_PIRQ 6 // Generic: 8 | De-RISC: 6
#endif
#ifndef GPTIMER_PIRQ
#define GPTIMER_PIRQ 2
#endif
#ifndef GPETH_IRQ
#define GPETH_IRQ 5
#endif

#define APBUART_SYSTEST (1 << 0)
#define SPIMCTRL_SYSTEST (1 << 1)
#define SPICTRL_SYSTEST (1 << 2)
#define I2C_MST_SYSTEST (1 << 3)
#define I2C_SYSTEST (1 << 4)
#define GRCANFD_SYSTEST (1 << 5)
#define SPICTRL_IRQ_SYSTEST (1 << 6)
#define GPTIMER_SYSTEST (1 << 7)
#define GRIOMMU_SYSTEST (1 << 8)
#define GRETH_SYSTEST (1 << 9)
#define L2C_SYSTEST (1 << 10)

#ifndef SYSTEST_TYPE
#define SYSTEST_TYPE L2C_SYSTEST
#endif

void print_test_result(int test_failed, char* dev_string) {
  if (CONSOLE_DEBUG) {
    if (test_failed) {
      printf("[ERROR] %s test failed with code: %d (OR-ed)\n", dev_string, test_failed);
    } else {
      printf("[INFO] %s test(s) passed.\n", dev_string);
    }
  }
}

/*
 *
 * For testing NOELV-based designs, the macro NOELV_SYSTEST must be defined.
 * The testing modules base addresses and interrupt IDs (if present) must be
 * changed accordingly.
 *
 * For defining parameters while compiling, run:
 *    make soft SYSTEST_DEFINES="-DNOELV_SYSTEST -DSYSTEST_TYPE=L2C_SYSTEST"
 *
 * The systests require an instantiated AHBREP module. The address of the AHBREP
 * must be changed accordingly by adding -DGRLIB_REPORTDEV_BASE=0x0...0 to the
 * SYSTEST_DEFINES variable. Default: 0x80000000
 *
 * Multiple modules can be tested in the same run by or-ing their test
 * identifiers, for example:
 *    make soft SYSTEST_DEFINES="-DNOELV_SYSTEST -DSYSTEST_TYPE='GRIOMMU_SYSTEST|GRETH_SYSTEST'"
 * This will run both GRIOMMU and GRETH tests (note the single quotes around the
 * SYSTEST_TYPE definition and the double quotes for the SYSTEST_DEFINES).
 *
 */
int main() {
  int test_failed = 0;
	report_start();

  if ((SYSTEST_TYPE) & APBUART_SYSTEST) {
    addr_t apbuart_addr = APBUART_ADDR_SYSTEST;
    test_failed |= apbuart_test(apbuart_addr);
    print_test_result(test_failed, "Generic UART");
  }
  if ((SYSTEST_TYPE) & SPIMCTRL_SYSTEST) { // test passed.
    addr_t spim_addr = SPIMCTRL_ADDR_SYSTEST;
    test_failed |= spimctrl_test(spim_addr);
    print_test_result(test_failed, "SPI Memory Controller");
  }
  if ((SYSTEST_TYPE) & SPICTRL_SYSTEST) {
    // NOTE: testsel 2 will call `spictrl_extdev_test()`. Check `spictrl.c` for
    // more information.
    int testsel = 0;
    addr_t spi_addr = SPICTRL_ADDR_SYSTEST;
    test_failed |= spictrl_test(spi_addr, testsel);
    print_test_result(test_failed, "SPI Controller");
  }
  if ((SYSTEST_TYPE) & SPICTRL_IRQ_SYSTEST) {
    addr_t spi_addr = SPICTRL_ADDR_SYSTEST;
    int spi_pirq = SPICTRL_PIRQ;
    test_failed |= spictrl_irqtest(spi_addr, spi_pirq);
    print_test_result(test_failed, "SPI Memory Controller with IRQ");
  }
  if ((SYSTEST_TYPE) & I2C_MST_SYSTEST) {
    addr_t i2c_mst_addr = I2C_MST_ADDR_SYSTEST;
    test_failed |= i2cmst_test(i2c_mst_addr);
    print_test_result(test_failed, "I2C Master");
  }
  if ((SYSTEST_TYPE) & I2C_SYSTEST) {
    addr_t i2c_mst_addr = I2C_MST_ADDR_SYSTEST;
    addr_t i2c_slv_addr = I2C_SLV_ADDR_SYSTEST;
    test_failed |= i2c_test(i2c_mst_addr, i2c_slv_addr);
    print_test_result(test_failed, "I2C Master+Slave");
  }
  if ((SYSTEST_TYPE) & GRCANFD_SYSTEST) {
    addr_t grcanfd_addr = GRCANFD_ADDR_SYSTEST;
    test_failed |= grcanfd_test(grcanfd_addr);
    print_test_result(test_failed, "CANFD");
  }
  if ((SYSTEST_TYPE) & GPTIMER_SYSTEST) {
    addr_t gptimer_addr = GPTIMER_ADDR_SYSTEST;
    int gptimer_pirq = GPTIMER_PIRQ;
    test_failed |= gptimer_test(gptimer_addr, gptimer_pirq);
    print_test_result(test_failed, "GPTimer");
  }
  if ((SYSTEST_TYPE) & GRIOMMU_SYSTEST) {
    addr_t griommu_addr = GRIOMMU_ADDR_SYSTEST;
    test_failed |= griommu_test(griommu_addr);
    print_test_result(test_failed, "GRIOMMU");
  }
  if ((SYSTEST_TYPE) & GRETH_SYSTEST) {
    printf("Starting GRETH test\n");
    addr_t greth_addr = GRETH_ADDR_SYSTEST;
    test_failed |= greth_test(greth_addr);
    print_test_result(test_failed, "GRETH");
  }
  if ((SYSTEST_TYPE) & L2C_SYSTEST) {
    printf("Starting L2C test\n");
    addr_t l2c_addr = L2C_ADDR_SYSTEST;
    // unsigned int l2_ctrl = *((addr_t*)L2C_ADDR_SYSTEST);
    // *((addr_t*)L2C_ADDR_SYSTEST) = l2_ctrl | (1 << 31); // Enable L2 before test
    l2c_enable(l2c_addr);
    char* memaddr = 0x0ULL;
    test_failed |= l2c_test(memaddr, (struct l2cregs*)l2c_addr);
    print_test_result(test_failed, "L2Cache");
  }
  print_test_result(test_failed, "All");
  report_end();
	return 0;
}
