#include <stdio.h>
#include "report.h"

#define DISABLE 0x0
#define ENABLE_RX 0x1
#define ENABLE_TX 0x2
#define RX_INT 0x4
#define TX_INT 0x8
#define EVEN_PARITY 0x20
#define ODD_PARITY 0x30
#define LOOP_BACK 0x80
#define FLOW_CONTROL 0x40
#define FIFO_TX_INT 0x200
#define FIFO_RX_INT 0x400

static inline int loadmem(addr_t addr) {
  int tmp;
#ifdef NOELV_SYSTEST
  asm volatile ("lw %0, 0(%1)"
#else
  asm volatile (" lda [%1]1, %0 "
#endif
    : "=r"(tmp)
    : "r"(addr)
  );
  return tmp;
}

struct uart_regs {
   volatile uint32_t data;
   volatile uint32_t status;
   volatile uint32_t control;
   volatile uint32_t scaler;
};

#define FIFO_RX_CNT ((loadmem((addr_t)&uart->status) >> 26) & 0x3F)
#define FIFO_TX_CNT ((loadmem((addr_t)&uart->status) >> 20) & 0x3F)
#define FIFO_TX_EMPTY ((loadmem((addr_t)&uart->status) >> 2) & 0x1)
#define FIFO_TX_FULL (loadmem((addr_t)&uart->status) & 0x200)
#define FIFO_RX_FULL (loadmem((addr_t)&uart->status) & 0x400)
#define FIFO_RX_HALF_FULL (loadmem((addr_t)&uart->status) & 0x100)
#define DATA_READY (loadmem((addr_t)&uart->status) & 1)
#define SHIFTREG_TX_EMPTY (loadmem((addr_t)&uart->status) & 2)

static char test[] = "40ti94a+0ygiyu05yhap5yi4h+a+iiyxhi4k59j0q905jkoyphoptjrhia4iy0+4";
static int testsize = sizeof test / sizeof test[0];

int apbuart_test(addr_t addr) {
  struct uart_regs *uart = (struct uart_regs *) addr;
  int temp;
  int i;
  int fifosize;
  if (report_device(0x0100C000)) return 17;
  // Set scaler to low value to speed up simulations
  uart->scaler = 1;
  uart->status = 0;
  // Initialize receiver holding register to prevent X in gate level simulation
  uart->control = ENABLE_TX | ENABLE_RX | LOOP_BACK;
  for (i = 0; i < 100; i++) {
    uart->data = 0;
  }
  for (i = 0; i < 100; i++) {
    temp = uart->data;
  }
  /*
   * DETERMINE fifosize
   */
  while (FIFO_TX_EMPTY != 1);
  // NOTE: Disabling is not working, enable the opposite instead.
  // uart->control = DISABLE; // NOTE: disabled for avoiding infinite loops.
  uart->control = ENABLE_RX;
  fifosize = 0;
  uart->data = 0;
  while (fifosize <= FIFO_TX_CNT) {
    fifosize++;
    uart->data = 0;
  }
  if (fifosize > 1) {
    fifosize--;
  }
  // Set counters to 0, and status bits to reset values
  uart->control = ENABLE_RX | ENABLE_TX;
  temp = loadmem((addr_t)&uart->status);
  while ((temp & 1) || !(temp & 4) || !(temp & 2) ) {
    while ((temp & 1) || !(temp & 4) || !(temp & 2) ) {
      temp = loadmem((addr_t)&uart->data);
      temp = loadmem((addr_t)&uart->status);
    }
    temp = loadmem((addr_t)&uart->status);
  }
  // NOTE: Disabling is not working, enable the opposite instead.
  // uart->control = DISABLE; // NOTE: disabled for avoiding infinite loops.
  uart->control = ENABLE_RX;
  /*
   * TRANSMITTER TEST
   */
  // NOTE: Transmit FIFO is expected to be less than half full, since it is
  // empty.
	// NOTE: This test is temporarily removed.
  if (fifosize > 1) {
    // if (((loadmem((addr_t)&uart->status) & 0x80) != 0) ) {
    //   fail(4); // th bit incorrect
    //   return 4;
    // }
  }
  uart->data = (addr_t) test[0];
	// // NOTE: This test will fail if CONSOLE is set to 1, which it is in most
	// // template designs, since they will have CFG_DUART set to 1
	// if ((loadmem((addr_t)&uart->status) & 4) == 4) {
	//   fail(1); // te bit incorrect
	// }
  if (SHIFTREG_TX_EMPTY == 0) {
    fail(2); // ts bit incorrect
    return 2;
  }
  if (fifosize > 1) {
    for (i = 1; i < fifosize; i++) {
      uart->data = (addr_t) test[i % testsize];
    }
		// NOTE: This test is temporarily removed
		// if (((loadmem((addr_t)&uart->status) & 0x80) == 0x80) ) {
		//   /*th bit incorrect*/
		//   fail(5);
    //   return 5;
		// }
    if (FIFO_TX_CNT != fifosize) {
      fail(6); // tcnt error
      return 6;
    }
    if (FIFO_TX_FULL == 0) {
      fail(7); // tf bit incorrect
      return 7;
    }
  }
  /*
   * RECEIVER TEST (WITH LOOPBACK)
   */
  if (DATA_READY != 0) {
    fail(15); // dr bit incorrect
    return 15;
  }
  uart->control = ENABLE_TX | ENABLE_RX | LOOP_BACK;
  if (fifosize == 1) {
    while (DATA_READY == 0);
  } else {
    while (FIFO_RX_FULL == 0); // Wait until receiver FIFO is NOT full.
  }
  if (DATA_READY == 0) {
    fail(8); // dr bit incorrect
    return 8;
  }
  if (fifosize > 1) {
    if ((FIFO_RX_CNT) != fifosize) {
      fail(9); // rcnt error
      return 9;
    }
    if (FIFO_RX_HALF_FULL == 0) {
      fail(10); // rhalffull error
      return 10;
    }
    if (FIFO_RX_FULL == 0) {
      fail(11); // rfull error
      return 11;
    }
  }
  for (i = 0; i < fifosize; i++) {
    temp = loadmem((addr_t)&uart->data);
    if (temp != test[i % testsize]) {
      fail(12); // data error
      return 12;
    }
  }
  if (fifosize > 1) {
    if (FIFO_RX_HALF_FULL != 0) {
      fail(13); // rhalffull error
      return 13;
    }
    if ((FIFO_RX_CNT) != 0) {
      fail(14); // rcnt error
      return 14;
    }
    if (FIFO_RX_FULL != 0) {
      fail(11); // rfull error
      return 11;
    }
  }
  if (DATA_READY != 0) {
    fail(16); // dr bit error
    return 16;
  }
  // uart->control = DISABLE; // NOTE: commented for avoiding infinite loops.
  return 0;
}
